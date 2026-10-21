import AudioSetCore
import AudioSetInfrastructure
import XCTest

final class FileSystemProfileStoreTests: XCTestCase {

    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioSetTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    private let sampleState = PersistedProfileState(
        profiles: [
            AudioProfile(id: "movie", name: "Кино", symbolName: "film", volume: Volume(percent: 65)),
            AudioProfile(id: "quiet", name: "Тихий", symbolName: "moon.zzz", volume: Volume(percent: 25)),
        ],
        activeProfileID: "quiet")

    func test_missingFileLoadsEmptyState() throws {
        let store = FileSystemProfileStore(fileURL: makeTempFileURL())
        XCTAssertEqual(try store.load(), .empty)
    }

    func test_roundTripPreservesState() throws {
        let url = makeTempFileURL()
        let store = FileSystemProfileStore(fileURL: url)
        try store.save(sampleState)

        let reloaded = FileSystemProfileStore(fileURL: url)
        XCTAssertEqual(try reloaded.load(), sampleState)
    }

    func test_corruptFileLoadsEmptyState() throws {
        let url = makeTempFileURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try "not json{".data(using: .utf8)?.write(to: url)

        let store = FileSystemProfileStore(fileURL: url)
        XCTAssertEqual(try store.load(), .empty, "повреждённый файл не должен валить приложение")
    }
}
