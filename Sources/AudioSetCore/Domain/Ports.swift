/// Снимок сохраняемого состояния: каталог профилей, выбранный профиль и версия
/// набора дефолтных профилей, которой соответствует каталог (для миграций).
public struct PersistedProfileState: Equatable, Sendable {
    public var profiles: [AudioProfile]
    public var activeProfileID: AudioProfile.ID?
    /// Версия дефолтного набора на момент последней записи;
    /// 0 — файлы, созданные до версионирования.
    public var seedVersion: Int

    public init(
        profiles: [AudioProfile] = [],
        activeProfileID: AudioProfile.ID? = nil,
        seedVersion: Int = 0
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.seedVersion = seedVersion
    }

    public static let empty = PersistedProfileState()
}

/// Driven-порт: управление системной громкостью (ядро не знает про CoreAudio).
public protocol VolumeSettingGateway: AnyObject {
    /// Устанавливает громкость устройства вывода по умолчанию.
    /// Громкость 0 означает mute.
    func apply(_ volume: Volume) async throws

    /// Текущая громкость, если её удалось прочитать.
    func currentVolume() async -> Volume?
}

/// Driven-порт: хранение каталога профилей и выбранного профиля
/// (ядро не знает про файловую систему).
public protocol ProfileStore: AnyObject {
    func load() throws -> PersistedProfileState
    func save(_ state: PersistedProfileState) throws
}
