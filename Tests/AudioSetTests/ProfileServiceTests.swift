import AudioSetCore
import XCTest

// MARK: - Тестовые двойники (замена driven-адаптеров)

private actor SpyVolumeGateway: VolumeSettingGateway {
    private(set) var applied: [Volume] = []
    var error: Error?
    var stubCurrent: Volume?

    func apply(_ volume: Volume) async throws {
        if let error {
            throw error
        }
        applied.append(volume)
    }

    func currentVolume() async -> Volume? {
        stubCurrent
    }
}

private final class InMemoryStore: ProfileStore {
    var state: PersistedProfileState
    private(set) var saveCalls: [PersistedProfileState] = []
    var saveError: Error?

    init(state: PersistedProfileState = .empty) {
        self.state = state
    }

    func load() throws -> PersistedProfileState {
        state
    }

    func save(_ state: PersistedProfileState) throws {
        if let saveError {
            throw saveError
        }
        saveCalls.append(state)
        self.state = state
    }
}

private struct StubError: Error {}

// MARK: - Тесты use cases

final class ProfileServiceTests: XCTestCase {

    private func profile(_ id: String, percent: Int) -> AudioProfile {
        AudioProfile(id: id, name: id, symbolName: "speaker.wave.2", volume: Volume(percent: percent))
    }

    private func makeService(
        gateway: SpyVolumeGateway = SpyVolumeGateway(),
        store: InMemoryStore = InMemoryStore()
    ) async throws -> ProfileService {
        try ProfileService(
            store: store,
            gateway: gateway,
            defaultProfiles: [profile("default", percent: 50)])
    }

    func test_seedsDefaultsAndPersistsWhenStoreEmpty() async throws {
        let store = InMemoryStore()
        let service = try await makeService(store: store)

        let catalog = await service.catalog()

        XCTAssertEqual(catalog.profiles.map(\.id), ["default"])
        XCTAssertEqual(store.saveCalls.count, 1, "засеивание должно сохраняться на диск")
    }

    func test_loadsExistingProfilesWithoutReseeding() async throws {
        let stored = [profile("custom", percent: 77)]
        let store = InMemoryStore(
            state: PersistedProfileState(profiles: stored, activeProfileID: "custom"))
        let service = try await makeService(store: store)

        let catalog = await service.catalog()

        XCTAssertEqual(catalog.profiles.map(\.id), ["custom"])
        XCTAssertEqual(catalog.activeProfileID, "custom")
        XCTAssertTrue(store.saveCalls.isEmpty, "существующий каталог не должен перезаписываться")
    }

    func test_activateAppliesVolumeAndPersistsSelection() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("low", percent: 30), profile("high", percent: 80)]))
        let gateway = SpyVolumeGateway()
        let service = try await makeService(gateway: gateway, store: store)

        let activated = try await service.activate(profileID: "high")
        let applied = await gateway.applied
        let catalog = await service.catalog()

        XCTAssertEqual(activated, profile("high", percent: 80))
        XCTAssertEqual(applied, [Volume(percent: 80)])
        XCTAssertEqual(catalog.activeProfileID, "high")
        XCTAssertEqual(store.state.activeProfileID, "high")
    }

    func test_activateUnknownProfileThrowsAndAppliesNothing() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("movie", percent: 65)]))
        let gateway = SpyVolumeGateway()
        let service = try await makeService(gateway: gateway, store: store)

        do {
            _ = try await service.activate(profileID: "ghost")
            XCTFail("ожидалась ошибка profileNotFound")
        } catch {
            XCTAssertEqual(error as? ProfileServiceError, .profileNotFound("ghost"))
        }
        let applied = await gateway.applied
        let catalog = await service.catalog()
        XCTAssertTrue(applied.isEmpty)
        XCTAssertTrue(store.saveCalls.isEmpty)
        XCTAssertNil(catalog.activeProfileID)
    }

    func test_gatewayFailureDoesNotPersistSelection() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("movie", percent: 65)]))
        let gateway = SpyVolumeGateway()
        await gateway.setError(StubError())
        let service = try await makeService(gateway: gateway, store: store)

        do {
            _ = try await service.activate(profileID: "movie")
            XCTFail("ожидалась ошибка шлюза")
        } catch {
            XCTAssertTrue(error is StubError)
        }
        let applied = await gateway.applied
        let catalog = await service.catalog()
        XCTAssertTrue(applied.isEmpty)
        XCTAssertTrue(store.saveCalls.isEmpty, "выбор не сохраняется при ошибке применения")
        XCTAssertNil(catalog.activeProfileID, "выбор не меняется в памяти при ошибке применения")
    }

    func test_setCustomVolumeClearsActiveProfileAndPersists() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("movie", percent: 65)]))
        let gateway = SpyVolumeGateway()
        let service = try await makeService(gateway: gateway, store: store)

        _ = try await service.activate(profileID: "movie")
        try await service.setCustomVolume(Volume(percent: 15), persistSelection: true)

        let applied = await gateway.applied
        let catalog = await service.catalog()
        XCTAssertEqual(applied.last, Volume(percent: 15))
        XCTAssertNil(catalog.activeProfileID, "ручная громкость сбрасывает выбор профиля")
        XCTAssertNil(store.state.activeProfileID)
    }

    func test_setCustomVolumeDuringDragSkipsDiskWrite() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("movie", percent: 65)]))
        let service = try await makeService(store: store)

        _ = try await service.activate(profileID: "movie")
        let savesBeforeDrag = store.saveCalls.count
        try await service.setCustomVolume(Volume(percent: 20), persistSelection: false)

        let catalog = await service.catalog()
        XCTAssertEqual(store.saveCalls.count, savesBeforeDrag, "перетаскивание не пишет на диск")
        XCTAssertNil(catalog.activeProfileID, "выбор сброшен в памяти сразу")
    }

    func test_migrationAppendsNewDefaultsAndKeepsUserEdits() async throws {
        let editedMovie = AudioProfile(
            id: "movie", name: "Кино", symbolName: "film", volume: Volume(percent: 90))
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [editedMovie, profile("custom", percent: 33)],
            activeProfileID: "custom",
            seedVersion: 1))
        let newDefaults = [profile("movie", percent: 65), profile("night", percent: 15)]

        let service = try ProfileService(
            store: store,
            gateway: SpyVolumeGateway(),
            defaultProfiles: newDefaults,
            defaultProfileSetVersion: 2)

        let catalog = await service.catalog()
        XCTAssertEqual(catalog.profiles.map(\.id), ["movie", "custom", "night"],
                       "порядок сохранён, новые профили — в конец")
        XCTAssertEqual(catalog.profiles[0].volume, Volume(percent: 90),
                       "пользовательская правка громкости не перезаписана дефолтом")
        XCTAssertEqual(catalog.activeProfileID, "custom", "выбранный профиль не сбрасывается")
        XCTAssertEqual(store.state.seedVersion, 2)
        XCTAssertEqual(store.saveCalls.count, 1)
    }

    func test_noMigrationWhenSeedVersionCurrent() async throws {
        let store = InMemoryStore(state: PersistedProfileState(
            profiles: [profile("movie", percent: 65)],
            seedVersion: 2))

        _ = try ProfileService(
            store: store,
            gateway: SpyVolumeGateway(),
            defaultProfiles: [profile("movie", percent: 65), profile("night", percent: 15)],
            defaultProfileSetVersion: 2)

        XCTAssertTrue(store.saveCalls.isEmpty, "каталог актуальной версии не перезаписывается")
    }
}

private extension SpyVolumeGateway {
    func setError(_ error: Error?) {
        self.error = error
    }
}
