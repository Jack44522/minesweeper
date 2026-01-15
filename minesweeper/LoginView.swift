//
//  LoginView.swift
//  minesweeper
//
//  Created by 蔡偉杰 on 14/1/2026.
//

// LoginView.swift
import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isRegisterMode = false
    
    @Environment(AuthViewModel.self) private var authVM
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(isRegisterMode ? "註冊" : "登入")
                    .font(.largeTitle.bold())
                
                VStack(spacing: 20) {
                    TextField("使用者名稱", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    SecureField("密碼", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                Button(isRegisterMode ? "註冊" : "登入") {
                    if isRegisterMode {
                        authVM.register(username: username, password: password)
                    } else {
                        authVM.signIn(username: username, password: password)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authVM.isLoading || username.isEmpty || password.isEmpty)
                
                Button(isRegisterMode ? "已有帳號？登入" : "還沒有帳號？註冊") {
                    isRegisterMode.toggle()
                }
                .font(.footnote)
            }
            .padding()
            .navigationTitle("歡迎來到踩地雷")
        }
    }
}
