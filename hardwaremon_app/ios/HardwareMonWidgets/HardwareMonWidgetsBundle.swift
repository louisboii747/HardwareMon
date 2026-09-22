import SwiftUI
import WidgetKit

@main
struct HardwareMonWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HardwareMonWidgets()

        #if os(iOS)
        HardwareActivityWidget()
        #endif
    }
}
