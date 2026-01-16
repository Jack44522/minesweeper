import SwiftUI
import FirebaseCore

@main
struct MinesweeperApp: App {
    init() {
        FirebaseApp.configure()  // 第一時間呼叫firebase
    }
    
    var body: some Scene {
        WindowGroup {
            AuthWrapperView()  // 判斷登入狀態的包裝視圖
        }
    }
}
