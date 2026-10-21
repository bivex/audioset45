/// Политика приложения: профили первого запуска и их версионирование.
/// Пользователь может менять их в ~/Library/Application Support/AudioSet/profiles.json.
public enum DefaultProfiles {

    /// Версия набора профилей. При увеличении ProfileService мигрирует существующий
    /// каталог: добавляет новые дефолтные профили, не трогая уже существующие
    /// (включая пользовательские правки громкости и порядка).
    ///
    /// v1 — movie, quiet, focus, party, silent.
    /// v2 — night, music, games, calls, ambient.
    public static let setVersion = 2

    public static let standard: [AudioProfile] = [
        // v1
        AudioProfile(id: "movie", name: "Кино", symbolName: "film", volume: Volume(percent: 65)),
        AudioProfile(id: "quiet", name: "Тихий", symbolName: "moon.zzz", volume: Volume(percent: 25)),
        AudioProfile(id: "focus", name: "Фокус", symbolName: "brain.head.profile", volume: Volume(percent: 40)),
        AudioProfile(id: "party", name: "Вечеринка", symbolName: "party.popper", volume: Volume(percent: 100)),
        AudioProfile(id: "silent", name: "Беззвучный", symbolName: "speaker.slash.fill", volume: Volume(percent: 0)),
        // v2
        AudioProfile(id: "night", name: "Ночной", symbolName: "moon.stars", volume: Volume(percent: 15)),
        AudioProfile(id: "music", name: "Музыка", symbolName: "music.quarternote.3", volume: Volume(percent: 80)),
        AudioProfile(id: "games", name: "Игры", symbolName: "gamecontroller", volume: Volume(percent: 75)),
        AudioProfile(id: "calls", name: "Звонки", symbolName: "phone", volume: Volume(percent: 55)),
        AudioProfile(id: "ambient", name: "Фон", symbolName: "waveform", volume: Volume(percent: 10)),
    ]
}
