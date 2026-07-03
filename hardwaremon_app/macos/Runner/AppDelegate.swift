import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  @IBAction func openHardwareMonSettings(_ sender: Any?) {
    (mainFlutterWindow as? MainFlutterWindow)?.sendMenuAction("openSettings")
    mainFlutterWindow?.makeKeyAndOrderFront(sender)
    NSApp.activate(ignoringOtherApps: true)
  }

  @IBAction func refreshHardwareMonTelemetry(_ sender: Any?) {
    (mainFlutterWindow as? MainFlutterWindow)?.sendMenuAction("refreshTelemetry")
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
