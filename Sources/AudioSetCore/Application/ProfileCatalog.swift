/// Read-модель каталога для UI: профили + активный выбор.
public struct ProfileCatalog: Equatable, Sendable {
    public let profiles: [AudioProfile]
    public let activeProfileID: AudioProfile.ID?

    public init(profiles: [AudioProfile], activeProfileID: AudioProfile.ID?) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    public static let empty = ProfileCatalog(profiles: [], activeProfileID: nil)

    public var isEmpty: Bool { profiles.isEmpty }
}
