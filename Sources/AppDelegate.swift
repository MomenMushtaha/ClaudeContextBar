import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager()
    }
}
