import Foundation

public enum ProfileServiceError: Error, LocalizedError, Equatable {
    case profileNotFound(AudioProfile.ID)

    public var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "Профиль «\(id)» не найден в каталоге."
        }
    }
}

/// Application-сервис (use cases). Actor — все мутации состояния сериализованы,
/// UI вызывает через await.
///
/// Инвариант упорядочивания: громкость применяется к системе ДО сохранения выбора.
/// Если применение не удалось, выбор не меняется ни в памяти, ни на диске.
public actor ProfileService {
    private let store: ProfileStore
    private let gateway: VolumeSettingGateway
    private var state: PersistedProfileState

    /// Загружает состояние. Пустой каталог засеивается дефолтными профилями.
    /// Каталог более старой версии (`seedVersion < defaultProfileSetVersion`)
    /// мигрируется: недостающие дефолтные профили добавляются в конец,
    /// существующие (включая пользовательские правки и порядок) не трогаются.
    public init(
        store: ProfileStore,
        gateway: VolumeSettingGateway,
        defaultProfiles: [AudioProfile],
        defaultProfileSetVersion: Int = 0
    ) throws {
        self.store = store
        self.gateway = gateway

        var loaded = try store.load()
        if loaded.profiles.isEmpty {
            loaded.profiles = defaultProfiles
            loaded.seedVersion = defaultProfileSetVersion
            try store.save(loaded)
        } else if loaded.seedVersion < defaultProfileSetVersion {
            let knownIDs = Set(loaded.profiles.map(\.id))
            loaded.profiles.append(contentsOf: defaultProfiles.filter { !knownIDs.contains($0.id) })
            loaded.seedVersion = defaultProfileSetVersion
            try store.save(loaded)
        }
        self.state = loaded
    }

    /// Снимок каталога для UI.
    public func catalog() -> ProfileCatalog {
        ProfileCatalog(profiles: state.profiles, activeProfileID: state.activeProfileID)
    }

    /// Применяет профиль: громкость в систему, затем выбор — в память и на диск.
    @discardableResult
    public func activate(profileID: AudioProfile.ID) async throws -> AudioProfile {
        guard let profile = state.profiles.first(where: { $0.id == profileID }) else {
            throw ProfileServiceError.profileNotFound(profileID)
        }
        try await gateway.apply(profile.volume)
        state.activeProfileID = profileID
        try store.save(state)
        return profile
    }

    /// Ручная громкость ползунком: выбор профиля сбрасывается.
    /// `persistSelection == false` используется во время перетаскивания,
    /// чтобы не писать на диск на каждый тик.
    public func setCustomVolume(_ volume: Volume, persistSelection: Bool) async throws {
        try await gateway.apply(volume)
        state.activeProfileID = nil
        if persistSelection {
            try store.save(state)
        }
    }

    /// Текущая системная громкость (для отображения, без throw).
    public func currentSystemVolume() async -> Volume? {
        await gateway.currentVolume()
    }
}
