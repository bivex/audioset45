import AudioSetCore
import CoreAudio
import Foundation

public enum CoreAudioError: Error, LocalizedError {
    case noDefaultOutputDevice
    case volumeNotAdjustable
    case propertyFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .noDefaultOutputDevice:
            return "Выходное аудиоустройство не найдено."
        case .volumeNotAdjustable:
            return "Устройство не поддерживает регулировку громкости."
        case .propertyFailed(let status):
            return "Не удалось изменить громкость (код ошибки CoreAudio: \(status))."
        }
    }
}

/// Driven-адаптер порта VolumeSettingGateway поверх CoreAudio.
///
/// Громкость пишется поканально (kAudioDevicePropertyVolumeScalar по каналам из
/// PreferredChannelsForStereo); если устройство не поддерживает поканальную громкость
/// (например, агрегированное), — через VolumeScalar на мастер-элементе. Громкость 0 реализуется
/// как mute; любая громкость > 0 снимает mute.
public final class CoreAudioVolumeGateway: VolumeSettingGateway {

    public init() {}

    public func apply(_ volume: Volume) async throws {
        let device = try Self.defaultOutputDevice()
        try Self.write(volume: volume, to: device)
    }

    public func currentVolume() async -> Volume? {
        guard let device = try? Self.defaultOutputDevice() else { return nil }
        return Self.readVolume(of: device)
    }

    // MARK: - CoreAudio

    private static func defaultOutputDevice() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != 0 else {
            throw CoreAudioError.noDefaultOutputDevice
        }
        return device
    }

    private static func write(volume: Volume, to device: AudioDeviceID) throws {
        setMuted(volume.isSilent, on: device)
        guard !volume.isSilent else { return }

        let scalar = Float32(volume.percent) / 100
        var channelApplied = false
        for channel in stereoChannels(of: device) {
            let ok = (try? setChannelScalar(scalar, channel: channel, device: device)) ?? false
            channelApplied = channelApplied || ok
        }
        if !channelApplied {
            try setMasterScalar(scalar, device: device)
        }
    }

    /// Пара каналов устройства для стерео; фолбэк — [1, 2].
    private static func stereoChannels(of device: AudioDeviceID) -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var pair = (left: UInt32(1), right: UInt32(2))
        var size = UInt32(MemoryLayout.size(ofValue: pair))
        let status = withUnsafeMutableBytes(of: &pair) { raw -> OSStatus in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw.baseAddress!)
        }
        return status == noErr ? [pair.left, pair.right] : [1, 2]
    }

    /// Устанавливает громкость одного канала. false — свойство не поддерживается.
    private static func setChannelScalar(
        _ scalar: Float32, channel: UInt32, device: AudioDeviceID
    ) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value = scalar
        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        guard status == noErr else { throw CoreAudioError.propertyFailed(status: status) }
        return true
    }

    /// Фолбэк для устройств без поканальной громкости (агрегаты, виртуальные):
    /// VolumeScalar на мастер-элементе устройства.
    private static func setMasterScalar(_ scalar: Float32, device: AudioDeviceID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else {
            throw CoreAudioError.volumeNotAdjustable
        }
        var value = scalar
        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        guard status == noErr else { throw CoreAudioError.propertyFailed(status: status) }
    }

    /// Mute — best effort: не каждое устройство поддерживает свойство.
    private static func setMuted(_ muted: Bool, on device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private static func readVolume(of device: AudioDeviceID) -> Volume? {
        var values: [Float32] = []
        for channel in stereoChannels(of: device) {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel)
            guard AudioObjectHasProperty(device, &address) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
                continue
            }
            values.append(value)
        }
        if values.isEmpty {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectHasProperty(device, &address) else { return nil }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
                return nil
            }
            values.append(value)
        }
        let average = values.reduce(0, +) / Float32(values.count)
        return Volume(percent: Int((average * 100).rounded()))
    }
}
