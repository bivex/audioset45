import AppKit
import AudioSetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service: ProfileService
    private var menuBarController: MenuBarController?

    init(service: ProfileService) {
        self.service = service
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController(service: service)
        controller.bootstrap()
        menuBarController = controller
    }
}
