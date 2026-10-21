import AppKit
import AudioSetCore
import AudioSetInfrastructure

// MARK: - Диагностика (CLI)
// Используются для проверки проводки CoreAudio без участия UI:
//   AudioSet --print-volume    — напечатать текущую громкость
//   AudioSet --reapply-volume  — прочитать громкость и записать её же обратно

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(message.utf8))
    exit(2)
}

let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--print-volume") || arguments.contains("--reapply-volume") {
    let gateway = CoreAudioVolumeGateway()
    guard let volume = await gateway.currentVolume() else {
        fail("output device not found\n")
    }
    if arguments.contains("--print-volume") {
        print(volume.percent)
    } else {
        do {
            try await gateway.apply(volume)
            print("reapplied \(volume.percent)%")
        } catch {
            fail("\(error.localizedDescription)\n")
        }
    }
    exit(0)
}

// MARK: - Приложение меню-бара

do {
    let service = try CompositionRoot.makeProfileService()
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory) // без иконки в Dock, только меню-бар
    let delegate = AppDelegate(service: service)
    app.delegate = delegate
    app.run()
} catch {
    fail("AudioSet: \(error.localizedDescription)\n")
}
