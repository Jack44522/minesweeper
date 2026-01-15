// AuthWrapperView.swift
import SwiftUI

struct AuthWrapperView: View {
    @State private var authVM = AuthViewModel()
    
    var body: some View {
        if authVM.isLoggedIn {
            MinesweeperView()
                .environment(authVM)  // 傳給遊戲畫面使用
        } else {
            LoginView()
                .environment(authVM)
        }
    }
}
