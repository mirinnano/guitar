import Darwin
import SwiftUI

@main
struct GuitarToolsMacApp: App {

    init() {
        if CommandLine
            .arguments
            .contains(
                "--smoke-test"
            ) {
            print(
                "Guitar Tools macOS smoke test OK"
            )
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 920,
                    minHeight: 640
                )
        }
        .defaultSize(
            width: 1_220,
            height: 820
        )
        .commands {
            CommandGroup(
                replacing: .newItem
            ) {
                EmptyView()
            }

            CommandMenu(
                "練習"
            ) {
                Button(
                    "再生 / 一時停止"
                ) {
                    NotificationCenter
                        .default
                        .post(
                            name:
                                .practiceTogglePlayback,
                            object: nil
                        )
                }
                .keyboardShortcut(
                    .return,
                    modifiers:
                        [.command]
                )

                Button(
                    "最初から"
                ) {
                    NotificationCenter
                        .default
                        .post(
                            name:
                                .practiceReset,
                            object: nil
                        )
                }
                .keyboardShortcut(
                    .leftArrow,
                    modifiers:
                        [
                            .command,
                            .shift
                        ]
                )

                Divider()

                Button(
                    "オーディオ入力を開始 / 停止"
                ) {
                    NotificationCenter
                        .default
                        .post(
                            name:
                                .toggleAudioInput,
                            object: nil
                        )
                }
                .keyboardShortcut(
                    "i",
                    modifiers:
                        [
                            .command,
                            .shift
                        ]
                )

                Button(
                    "インスペクタを表示 / 非表示"
                ) {
                    NotificationCenter
                        .default
                        .post(
                            name:
                                .practiceToggleInspector,
                            object: nil
                        )
                }
                .keyboardShortcut(
                    "i",
                    modifiers:
                        [
                            .command,
                            .option
                        ]
                )
            }
        }
    }
}
