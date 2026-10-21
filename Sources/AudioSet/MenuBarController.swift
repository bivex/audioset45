import AppKit
import AudioSetCore

/// Driving-адаптер: иконка и меню в меню-баре macOS.
///
/// Меню: текущая громкость → профили (галочка у активного) → ползунок
/// произвольной громкости → выход.
@MainActor
final class MenuBarController: NSObject {

    private let service: ProfileService
    private let statusItem: NSStatusItem
    private var catalog = ProfileCatalog.empty
    private var currentVolume: Volume?

    init(service: ProfileService) {
        self.service = service
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "speaker.wave.2.fill",
            accessibilityDescription: "AudioSet")
        statusItem.button?.toolTip = "AudioSet — профили громкости"

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        populate(menu)
    }

    /// Загружает каталог и текущую громкость, обновляет меню.
    func bootstrap() {
        Task { [weak self] in
            guard let self else { return }
            self.catalog = await self.service.catalog()
            self.currentVolume = await self.service.currentSystemVolume()
            self.refreshMenu()
            let percent = self.currentVolume.map { "\($0.percent)%" } ?? "н/д"
            FileHandle.standardError.write(Data("AudioSet: меню готово, профилей: \(self.catalog.profiles.count), громкость: \(percent)\n".utf8))
        }
    }

    // MARK: - Построение меню

    private func refreshMenu() {
        if let menu = statusItem.menu {
            populate(menu)
        }
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        let volumeTitle = currentVolume.map { "Громкость: \($0.percent)%" } ?? "Громкость: н/д"
        let volumeItem = NSMenuItem(title: volumeTitle, action: nil, keyEquivalent: "")
        volumeItem.isEnabled = false
        menu.addItem(volumeItem)
        menu.addItem(NSMenuItem.separator())

        for profile in catalog.profiles {
            let item = NSMenuItem(
                title: "\(profile.name) — \(profile.volume.percent)%",
                action: #selector(selectProfile(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id
            item.image = NSImage(
                systemSymbolName: profile.symbolName,
                accessibilityDescription: profile.name)
            item.state = catalog.activeProfileID == profile.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(sliderItem())

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(
            title: "Завершить AudioSet",
            action: #selector(quit),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func sliderItem() -> NSMenuItem {
        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        let slider = NSSlider(
            value: Double(currentVolume?.percent ?? 50),
            minValue: 0,
            maxValue: 100,
            target: self,
            action: #selector(volumeSliderChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 18, y: 4, width: 204, height: 22)
        slider.autoresizingMask = [.width]
        container.addSubview(slider)
        item.view = container
        return item
    }

    // MARK: - Действия

    @objc private func selectProfile(_ item: NSMenuItem) {
        guard let profileID = item.representedObject as? String else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let profile = try await self.service.activate(profileID: profileID)
                self.catalog = await self.service.catalog()
                self.currentVolume = profile.volume
                self.refreshMenu()
            } catch {
                self.presentError(error)
            }
        }
    }

    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        let volume = Volume(percent: Int(sender.intValue))
        let isFinalChange = NSApp.currentEvent?.type == .leftMouseUp
        Task { [service, weak self] in
            // Во время перетаскивания ошибки игнорируем: следующее движение повторит попытку.
            try? await service.setCustomVolume(volume, persistSelection: isFinalChange)
            if isFinalChange, let self {
                self.catalog = await service.catalog()
                self.currentVolume = volume
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Ошибки

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "AudioSet"
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

extension MenuBarController: NSMenuDelegate {
    /// Меню пересобирается при каждом открытии — состояние всегда актуально.
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }
}
