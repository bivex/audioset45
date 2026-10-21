import AudioSetCore
import Foundation

/// Driven-адаптер порта ProfileStore: JSON-файл в Application Support.
///
/// Повреждённый или отсутствующий файл трактуется как пустое состояние
/// (сервис пересоздаст дефолтные профили), а не как ошибка.
public final class FileSystemProfileStore: ProfileStore {

    /// Путь по умолчанию: ~/Library/Application Support/AudioSet/profiles.json
    public static var defaultFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioSet", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultFileURL
        }
    }

    public func load() throws -> PersistedProfileState {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).toState()
        } catch {
            return .empty
        }
    }

    public func save(_ state: PersistedProfileState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(state: state))
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - DTO (деталь адаптера, домен остаётся без Codable)

    private struct Envelope: Codable {
        var profiles: [ProfileRecord]
        var activeProfileID: String?
        var defaultProfileSetVersion: Int

        init(state: PersistedProfileState) {
            profiles = state.profiles.map { ProfileRecord(profile: $0) }
            activeProfileID = state.activeProfileID
            defaultProfileSetVersion = state.seedVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            profiles = try container.decodeIfPresent([ProfileRecord].self, forKey: .profiles) ?? []
            activeProfileID = try container.decodeIfPresent(String.self, forKey: .activeProfileID)
            // Файлы до версионирования поля не содержат — считаем версией 0.
            defaultProfileSetVersion =
                try container.decodeIfPresent(Int.self, forKey: .defaultProfileSetVersion) ?? 0
        }

        func toState() -> PersistedProfileState {
            PersistedProfileState(
                profiles: profiles.map { $0.toDomain() },
                activeProfileID: activeProfileID,
                seedVersion: defaultProfileSetVersion)
        }
    }

    private struct ProfileRecord: Codable {
        var id: String
        var name: String
        var symbol: String
        var volume: Int

        init(profile: AudioProfile) {
            id = profile.id
            name = profile.name
            symbol = profile.symbolName
            volume = profile.volume.percent
        }

        func toDomain() -> AudioProfile {
            AudioProfile(id: id, name: name, symbolName: symbol, volume: Volume(percent: volume))
        }
    }
}
