import SwiftUI
import DocCKit

/// Hosts the local DocCKit component playground in a standalone macOS window.
@main
struct DocCPlaygroundApp: App {
    var body: some Scene {
        WindowGroup("DocC Playground") {
            #if DEBUG
            DocCComponentPlayground()
                .frame(minWidth: 820, minHeight: 600)
            #else
            ContentUnavailableView(
                "Use the Debug configuration",
                systemImage: "hammer",
                description: Text("The mock component playground is available in Debug builds.")
            )
            #endif
        }
        .defaultSize(width: 1150, height: 800)
    }
}
