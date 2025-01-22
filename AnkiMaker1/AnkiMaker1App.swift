import SwiftUI
import AppKit

@main
struct AnkiMaker1App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .onAppear {
                    // 设置窗口标题和样式
                    if let window = NSApplication.shared.windows.first {
                        window.title = "AnkiMaker - 法语学习卡片生成器"
                        window.center()
                        
                        // 设置窗口最小尺寸
                        window.minSize = NSSize(width: 600, height: 500)
                        
                        // 设置窗口样式
                        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                        
                        // 设置窗口层级
                        window.level = .normal
                    }
                }
        }
        .commands {
            // 添加自定义菜单
            CommandGroup(replacing: .newItem) { }  // 移除 New 菜单项
            CommandGroup(replacing: .saveItem) { } // 移除 Save 菜单项
            
            CommandMenu("帮助") {
                Button("检查 Anki 连接") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CheckAnkiConnection"),
                        object: nil
                    )
                }
                .keyboardShortcut("R", modifiers: .command)
            }
        }
    }
}
