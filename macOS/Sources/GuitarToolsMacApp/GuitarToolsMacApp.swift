import SwiftUI

@main
struct GuitarToolsMacApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 860,
                    minHeight: 620
                )
        }
        .defaultSize(
            width: 1_080,
            height: 760
        )
        .commands {
            CommandGroup(
                replacing: .newItem
            ) {
                EmptyView()
            }
        }
    }
}
