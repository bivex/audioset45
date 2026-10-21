/// Профиль громкости: именованный предустановленный уровень для конкретного сценария
/// (кино, тихий режим и т.д.).
public struct AudioProfile: Identifiable, Hashable, Sendable {
    public typealias ID = String

    /// Стабильный семантический идентификатор ("movie", "quiet", ...).
    /// Используется для сохранения выбора, поэтому не должен меняться между запусками.
    public let id: ID
    /// Отображаемое имя в меню.
    public let name: String
    /// Имя SF Symbol для иконки в меню.
    public let symbolName: String
    /// Уровень громкости профиля.
    public let volume: Volume

    public init(id: ID, name: String, symbolName: String, volume: Volume) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.volume = volume
    }
}
