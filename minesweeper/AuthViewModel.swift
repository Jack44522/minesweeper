//
//  AuthViewModel.swift
//  minesweeper
//
//  Created by 蔡偉杰 on 14/1/2026.
//

// AuthViewModel.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

@Observable
class AuthViewModel {
    var currentUser: User? = nil
    var isLoading = false
    var errorMessage: String? = nil
    
    var isLoggedIn: Bool {
        currentUser != nil
    }
    
    init() {
        // 監聽登入狀態變化
        Auth.auth().addStateDidChangeListener { auth, user in
            self.currentUser = user
        }
    }
    
    func signIn(username: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Firebase 的 email/password 登入，但我們用 username@fake.com 模擬
        let email = "\(username)@minesweeper.local"  // 假 email，密碼真實
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            self.currentUser = result?.user
        }
    }
    
    func register(username: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        let email = "\(username)@minesweeper.local"
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            self.currentUser = result?.user
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
