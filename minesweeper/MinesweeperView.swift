import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - 難度等級
enum Difficulty {
    case easy  // 6x6, 6 mines
    case medium  // 9x9, 10 mines
    case hard  // 16x16, 40 mines
    
    var rows: Int {
        switch self {
        case .easy: return 6
        case .medium: return 9
        case .hard: return 16
        }
    }
    
    var columns: Int {
        switch self {
        case .easy: return 6
        case .medium: return 9
        case .hard: return 16
        }
    }
    
    var totalMines: Int {
        switch self {
        case .easy: return 6
        case .medium: return 10
        case .hard: return 40
        }
    }
    
    var label: String {
        switch self {
        case .easy: return "初級 (6x6, 6雷)"
        case .medium: return "中級 (9x9, 10雷)"
        case .hard: return "高級 (16x16, 40雷)"
        }
    }
    
    var string: String {
        switch self {
        case .easy: return "6x6"
        case .medium: return "9x9"
        case .hard: return "16x16"
        }
    }
}

// MARK: - 單個格子的模型
struct Cell: Identifiable {
    let id = UUID()
    var isMine = false
    var isRevealed = false
    var isFlagged = false
    var neighborMines = 0
}

// MARK: - 遊戲狀態管理
@Observable
class MinesweeperViewModel {
    var board: [[Cell]] = []
    var currentDifficulty: Difficulty = .easy
    var rows: Int = 6
    var columns: Int = 6
    var totalMines: Int = 6
    
    var gameOver = false
    var isWin = false
    var message = ""
    
    var elapsedTime: Int = 0
    private var timer: Timer? = nil
    
    func startNewGame(difficulty: Difficulty? = nil) {
        if let difficulty = difficulty {
            currentDifficulty = difficulty
        }
        
        rows = currentDifficulty.rows
        columns = currentDifficulty.columns
        totalMines = currentDifficulty.totalMines
        
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
            isWin = false
            message = "💥 踩到地雷了！用了 \(elapsedTime) 秒"
            stopTimer()
            revealAllMines()
            uploadRecord()
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
            uploadRecord()
        }
    }
    
    func uploadRecord() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let difficulty = currentDifficulty.string
        let revealedSafe = countRevealedSafe()
        
        let record: [String: Any] = [
            "difficulty": difficulty,
            "isWin": isWin,
            "mines": totalMines,
            "revealedSafe": revealedSafe,
            "time": elapsedTime,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("games").addDocument(data: record) { error in
            if let error = error {
                print("上傳失敗: \(error)")
            } else {
                print("記錄上傳成功！")
            }
        }
    }
    
    private func countRevealedSafe() -> Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if !board[r][c].isMine && board[r][c].isRevealed {
                    count += 1
                }
            }
        }
        return count
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
        let isWin: Bool
        let mines: Int
        let revealedSafe: Int
        let time: Int
        let timestamp: Date
    }
    
    private var stats: [String: (wins: Int, losses: Int, winRate: Double)] {
        var stats = [String: (wins: Int, losses: Int, winRate: Double)]()
        
        for record in records {
            var current = stats[record.difficulty] ?? (0, 0, 0.0)
            if record.isWin {
                current.wins += 1
            } else {
                current.losses += 1
            }
            let total = current.wins + current.losses
            current.winRate = total > 0 ? Double(current.wins) / Double(total) * 100 : 0
            stats[record.difficulty] = current
        }
        
        return stats
    }
    
    var body: some View {
        VStack {
            if !stats.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("統計")
                        .font(.headline)
                    
                    ForEach(stats.keys.sorted(), id: \.self) { diff in
                        let stat = stats[diff]!
                        Text("\(diff): 勝 \(stat.wins) / 敗 \(stat.losses) / 勝率 \(String(format: "%.1f%%", stat.winRate))")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            List(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.difficulty)
                        .font(.headline)
                    Text(record.isWin ? "勝利" : "失敗")
                        .foregroundStyle(record.isWin ? .green : .red)
                        .font(.subheadline)
                    Text("地雷數: \(record.mines)")
                    Text("翻開安全格: \(record.revealedSafe)")
                    Text("時間: \(record.time) 秒")
                        .foregroundStyle(.gray)
                    Text(record.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
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
                    print("讀取失敗: \(error?.localizedDescription ?? "")")
                    return
                }
                
                records = documents.compactMap { doc in
                    let data = doc.data()
                    guard let difficulty = data["difficulty"] as? String,
                          let isWin = data["isWin"] as? Bool,
                          let mines = data["mines"] as? Int,
                          let revealedSafe = data["revealedSafe"] as? Int,
                          let time = data["time"] as? Int,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    return GameRecord(difficulty: difficulty, isWin: isWin, mines: mines, revealedSafe: revealedSafe, time: time, timestamp: timestamp.dateValue())
                }
            }
    }
}

// MARK: - 主遊戲畫面
struct MinesweeperView: View {
    @State private var viewModel = MinesweeperViewModel()
    @Environment(AuthViewModel.self) private var authVM
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(viewModel.currentDifficulty.label)
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
                
                HStack {
                    Button("初級") {
                        viewModel.startNewGame(difficulty: .easy)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("中級") {
                        viewModel.startNewGame(difficulty: .medium)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("高級") {
                        viewModel.startNewGame(difficulty: .hard)
                    }
                    .buttonStyle(.bordered)
                }
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
        .onDisappear {
            viewModel.stopTimer()
        }
    }
    
    private var flagCount: Int {
        viewModel.board.flatMap { $0 }.filter { $0.isFlagged }.count
    }
}

// MARK: - 預覽
#Preview {
    let vm = MinesweeperViewModel()
    vm.startNewGame()
    return MinesweeperView()
        .environment(AuthViewModel())
}
