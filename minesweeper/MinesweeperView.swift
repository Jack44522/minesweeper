import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - 單個格子的模型
struct Cell: Identifiable {
    let id = UUID()
    var isMine = false
    var isRevealed = false
    var isFlagged = false
    var neighborMines = 0
}

// MARK: - 遊戲狀態管理（新增計時器）
@Observable
class MinesweeperViewModel {
    var board: [[Cell]] = []
    var rows = 6
    var columns = 6
    var totalMines = 6
    
    var gameOver = false
    var isWin = false
    var message = ""
    
    // 計時器相關
    var elapsedTime: Int = 0
    private var timer: Timer? = nil
    
    func startNewGame() {
        board = Array(repeating: Array(repeating: Cell(), count: columns), count: rows)
        
        var placed = 0
        while placed < totalMines {
            let row = Int.random(in: 0..<rows)
            let col = Int.random(in: 0..<columns)
            if !board[row][col].isMine {
                board[row][col].isMine = true
                placed += 1
            }
        }
        
        for r in 0..<rows {
            for c in 0..<columns {
                board[r][c].neighborMines = countNeighborMines(atRow: r, col: c)
            }
        }
        
        gameOver = false
        isWin = false
        message = ""
        elapsedTime = 0
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !self.gameOver {
                self.elapsedTime += 1
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func countNeighborMines(atRow row: Int, col: Int) -> Int {
        var count = 0
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                guard nr >= 0 && nr < rows && nc >= 0 && nc < columns else { continue }
                if board[nr][nc].isMine {
                    count += 1
                }
            }
        }
        return count
    }
    
    func reveal(row: Int, col: Int) {
        guard row >= 0, row < rows, col >= 0, col < columns else { return }
        guard !gameOver else { return }
        guard !board[row][col].isRevealed else { return }
        guard !board[row][col].isFlagged else { return }
        
        board[row][col].isRevealed = true
        
        if board[row][col].isMine {
            gameOver = true
            message = "💥 踩到地雷了！"
            stopTimer()
            revealAllMines()
            return
        }
        
        if board[row][col].neighborMines == 0 {
            floodFill(startRow: row, startCol: col)
        }
        
        checkWin()
    }
    
    private func floodFill(startRow: Int, startCol: Int) {
        var queue: [(Int, Int)] = [(startRow, startCol)]
        
        while !queue.isEmpty {
            let (row, col) = queue.removeFirst()
            
            guard row >= 0, row < rows, col >= 0, col < columns else { continue }
            guard !board[row][col].isRevealed else { continue }
            
            board[row][col].isRevealed = true
            
            if board[row][col].neighborMines == 0 {
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = row + dr
                        let nc = col + dc
                        guard nr >= 0, nr < rows, nc >= 0, nc < columns else { continue }
                        if !board[nr][nc].isRevealed && !board[nr][nc].isFlagged {
                            queue.append((nr, nc))
                        }
                    }
                }
            }
        }
    }
    
    private func revealAllMines() {
        for r in 0..<rows {
            for c in 0..<columns {
                if board[r][c].isMine {
                    board[r][c].isRevealed = true
                }
            }
        }
    }
    
    func toggleFlag(row: Int, col: Int) {
        guard row >= 0, row < rows, col >= 0, col < columns else { return }
        guard !gameOver else { return }
        guard !board[row][col].isRevealed else { return }
        
        var newBoard = board
        newBoard[row][col].isFlagged.toggle()
        board = newBoard
    }
    
    private func checkWin() {
        var unrevealedNonMines = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if !board[r][c].isMine && !board[r][c].isRevealed {
                    unrevealedNonMines += 1
                }
            }
        }
        if unrevealedNonMines == 0 {
            gameOver = true
            isWin = true
            message = "🎉 恭喜！你贏了！用了 \(elapsedTime) 秒"
            stopTimer()
            // 這裡上傳記錄（之後在 View 呼叫）
        }
    }
}

// MARK: - 單格顯示視圖
struct CellView: View {
    let board: [[Cell]]
    let row: Int
    let col: Int
    let onReveal: (Int, Int) -> Void
    let onToggleFlag: (Int, Int) -> Void
    
    private var cell: Cell {
        guard row >= 0 && row < board.count && col >= 0 && col < board[row].count else {
            return Cell()
        }
        return board[row][col]
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            
            Text(displayText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(textColor)
        }
        .frame(width: 44, height: 44)
        .onTapGesture {
            onReveal(row, col)
        }
        .contextMenu {
            Button(cell.isFlagged ? "取消旗幟" : "插旗") {
                onToggleFlag(row, col)
            }
        }
    }
    
    private var backgroundColor: Color {
        if cell.isRevealed {
            return cell.isMine ? .red.opacity(0.8) : .white
        } else if cell.isFlagged {
            return .yellow.opacity(0.7)
        } else {
            return .yellow.opacity(0.3)
        }
    }
    
    private var displayText: String {
        if cell.isRevealed {
            if cell.isMine { return "💣" }
            return cell.neighborMines == 0 ? " " : "\(cell.neighborMines)"
        } else if cell.isFlagged {
            return "🚩"
        } else {
            return ""
        }
    }
    
    private var textColor: Color {
        if cell.isRevealed {
            if cell.isMine { return .white }
            let colors: [Color] = [.blue, .green, .red, .purple, .brown, .cyan, .black, .gray]
            return cell.neighborMines > 0 ? colors[cell.neighborMines - 1] : .clear
        } else if cell.isFlagged {
            return .red
        } else {
            return .clear
        }
    }
}

// MARK: - 歷史紀錄頁面
struct HistoryView: View {
    @State private var records: [GameRecord] = []
    
    struct GameRecord: Identifiable {
        let id = UUID()
        let difficulty: String
        let time: Int
        let timestamp: Date
    }
    
    var body: some View {
        List(records) { record in
            HStack {
                Text(record.difficulty)
                Spacer()
                Text("\(record.time) 秒")
                    .foregroundStyle(.gray)
                Text(record.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .navigationTitle("歷史紀錄")
        .onAppear {
            loadRecords()
        }
    }
    
    private func loadRecords() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("games")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("讀取記錄失敗: \(error?.localizedDescription ?? "")")
                    return
                }
                
                records = documents.compactMap { doc in
                    let data = doc.data()
                    guard let difficulty = data["difficulty"] as? String,
                          let time = data["time"] as? Int,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    return GameRecord(difficulty: difficulty, time: time, timestamp: timestamp.dateValue())
                }
            }
    }
}

// MARK: - 主遊戲畫面（加計時器 + 歷史頁面導航 + 上傳記錄）
struct MinesweeperView: View {
    @State private var viewModel = MinesweeperViewModel()
    @Environment(AuthViewModel.self) private var authVM
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("踩地雷 - 初級 (6×6, 6雷)")
                    .font(.title.bold())
                
                HStack {
                    Text("剩餘地雷: \(viewModel.totalMines - flagCount)")
                    Spacer()
                    Text("時間: \(viewModel.elapsedTime) 秒")
                        .font(.headline)
                }
                .padding(.horizontal)
                
                Text(viewModel.message)
                    .foregroundStyle(viewModel.isWin ? .green : .red)
                    .font(.title2)
                    .padding()
                
                VStack(spacing: 4) {
                    ForEach(0..<viewModel.rows, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<viewModel.columns, id: \.self) { col in
                                CellView(
                                    board: viewModel.board,
                                    row: row,
                                    col: col,
                                    onReveal: viewModel.reveal,
                                    onToggleFlag: viewModel.toggleFlag
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("新遊戲") {
                    viewModel.startNewGame()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Minesweeper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登出") {
                        authVM.signOut()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("歷史") {
                        HistoryView()
                    }
                }
            }
        }
        .task {
            viewModel.startNewGame()
        }
        .onChange(of: viewModel.isWin) { newValue in
            if newValue {
                uploadWinRecord()
            }
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }
    
    private var flagCount: Int {
        viewModel.board.flatMap { $0 }.filter { $0.isFlagged }.count
    }
    
    private func uploadWinRecord() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let difficulty = "\(viewModel.rows)x\(viewModel.columns)"
        
        let record: [String: Any] = [
            "difficulty": difficulty,
            "time": viewModel.elapsedTime,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("games").addDocument(data: record) { error in
            if let error = error {
                print("上傳失敗: \(error)")
            } else {
                print("通關記錄上傳成功！")
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    let vm = MinesweeperViewModel()
    vm.startNewGame()
    return MinesweeperView()
        .environment(AuthViewModel())
}
