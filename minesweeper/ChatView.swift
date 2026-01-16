//
//  ChatView.swift
//  minesweeper
//
//  Created by 蔡偉杰 on 16/1/2026.
//

import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatView: View {
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    
    private let apiKey = "sk-789b213e679a45578ade0528f2285709"  // DeepSeek API Key
    private let apiURL = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        HStack {
                            if message.isUser {
                                Spacer()
                            }
                            
                            Text(message.text)
                                .padding()
                                .background(message.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(16)
                                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                            
                            if !message.isUser {
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("AI 正在思考...")
                                .foregroundStyle(.gray)
                        }
                        .padding()
                    }
                }
            }
            
            HStack {
                TextField("輸入訊息...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendMessage() }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("AI 聊天")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        messages.append(Message(text: userMessage, isUser: true))
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await callDeepSeekAPI(prompt: userMessage)
                await MainActor.run {
                    messages.append(Message(text: response, isUser: false))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(Message(text: "錯誤: \(error.localizedDescription)", isUser: false))
                    isLoading = false
                }
            }
        }
    }
    
    private func callDeepSeekAPI(prompt: String) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": false,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "DeepSeekError", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法解析回應"])
        }
        
        return content
    }
}

// MARK: - 預覽
#Preview {
    NavigationStack {
        ChatView()
    }
}
