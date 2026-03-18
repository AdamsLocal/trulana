import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  private var isMcpMode: Bool {
    ProcessInfo.processInfo.environment["TRULANA_MCP"] == "1"
    || ProcessInfo.processInfo.environment["SOVEREIGN_MCP"] == "1"
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !isMcpMode
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    if isMcpMode {
      NSApp.setActivationPolicy(.accessory)
      for window in NSApp.windows {
        window.orderOut(nil)
      }
    }
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
