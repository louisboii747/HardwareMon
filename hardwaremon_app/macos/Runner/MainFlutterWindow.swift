import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var menuChannel: FlutterMethodChannel?

  func sendMenuAction(_ action: String) {
    menuChannel?.invokeMethod(action, arguments: nil)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "HardwareMon"
    self.minSize = NSSize(width: 840, height: 560)

    let frameAutosaveName = "HardwareMonMainWindow"
    if !self.setFrameUsingName(frameAutosaveName),
       let visibleFrame = self.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
      let width = min(1180, visibleFrame.width * 0.92)
      let height = min(760, visibleFrame.height * 0.90)
      let origin = NSPoint(
        x: visibleFrame.midX - width / 2,
        y: visibleFrame.midY - height / 2
      )
      self.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
    }
    self.setFrameAutosaveName(frameAutosaveName)

    RegisterGeneratedPlugins(registry: flutterViewController)
    menuChannel = FlutterMethodChannel(
      name: "com.hardwaremon.HardwareMon/menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}
