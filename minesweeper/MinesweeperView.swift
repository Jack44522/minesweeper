import SwiftUI

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
    var rows = 6
    var columns = 6
    var totalMines = 6
    
    var gameOver = false
    var isWin = false
    var message = ""
    
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
            message = "🎉 恭喜！你贏了！"
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

// MARK: - 主遊戲畫面（新增登出功能）
struct MinesweeperView: View {
    @State private var viewModel = MinesweeperViewModel()
    @Environment(AuthViewModel.self) private var authVM  // 從環境取得 AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("踩地雷 - 初級 (6×6, 6雷)")
                    .font(.title.bold())
                
                HStack {
                    Text("剩餘地雷: \(viewModel.totalMines - flagCount)")
                    Spacer()
                    Text(viewModel.message)
                        .foregroundStyle(viewModel.isWin ? .green : .red)
                        .font(.headline)
                }
                .padding(.horizontal)
                
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
                    .font(.headline)
                }
            }
        }
        .task {
            viewModel.startNewGame()
        }
    }
    
    private var flagCount: Int {
        viewModel.board.flatMap { $0 }.filter { $0.isFlagged }.count
    }
}

// MARK: - 預覽（註：預覽時沒有 AuthViewModel 環境，所以會顯示登入畫面或錯誤）
#Preview {
    let vm = MinesweeperViewModel()
    vm.startNewGame()
    return MinesweeperView()
}
