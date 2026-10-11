import SwiftUI
import DocCKit

/// Hosts the local DocCKit component playground on Mac, iPhone, and iPad.
@main
struct DocCPlaygroundApp: App {
    var body: some Scene {
        WindowGroup("DocC Playground") {
            #if DEBUG
            DocCComponentPlayground()
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 600)
                #endif
            #else
            ContentUnavailableView(
                "Use the Debug configuration",
                systemImage: "hammer",
                description: Text("The mock component playground is available in Debug builds.")
            )
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1150, height: 800)
        #endif
    }
}
