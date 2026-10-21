/// Громкость в процентах. Инвариант домена: значение всегда в диапазоне 0...100.
/// Выходное значение за пределами диапазона сжимается (clamping).
public struct Volume: Hashable, Sendable {
    public let percent: Int

    public init(percent: Int) {
        self.percent = min(max(percent, 0), 100)
    }

    /// Полная тишина: на уровне железа применяется mute.
    public var isSilent: Bool { percent == 0 }
}
