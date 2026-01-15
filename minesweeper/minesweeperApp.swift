import SwiftUI
import FirebaseCore

@main
struct MinesweeperApp: App {
    init() {
        FirebaseApp.configure()  // 必須在第一時間呼叫
    }
    
    var body: some Scene {
        WindowGroup {
            AuthWrapperView()  // 判斷登入狀態的包裝視圖
        }
    }
}
