//
//  minesweeperTests.swift
//  minesweeperTests
//
//  Created by 蔡偉杰 on 14/1/2026.
//

import XCTest
@testable import minesweeper  

final class MinesweeperTests: XCTestCase {
    
    var viewModel: MinesweeperViewModel!
    
    override func setUpWithError() throws {
        viewModel = MinesweeperViewModel()
        viewModel.startNewGame(difficulty: .easy)  // 預設初級
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
    }
    
    // 測試：鄰近地雷計數是否正確
    func testCountNeighborMines() throws {
        // 手動模擬放置地雷
        viewModel.board[0][0].isMine = true
        viewModel.board[0][1].isMine = true
        viewModel.board[1][0].isMine = true
       
        
        // 測試 (1,1) 周圍應有 3 顆地雷
        XCTAssertEqual(viewModel.board[1][1].neighborMines, 3, "周圍應有 3 顆地雷")
        
        // 測試邊緣 (0,2) 周圍應有 2 顆
        XCTAssertEqual(viewModel.board[0][2].neighborMines, 2, "邊緣應有 2 顆地雷")
    }
    
    // 測試：插旗/取消插旗
    func testToggleFlag() throws {
        let initialFlagged = viewModel.board[0][0].isFlagged
        
        viewModel.toggleFlag(row: 0, col: 0)
        XCTAssertNotEqual(viewModel.board[0][0].isFlagged, initialFlagged, "旗幟狀態應切換")
        
        viewModel.toggleFlag(row: 0, col: 0)
        XCTAssertEqual(viewModel.board[0][0].isFlagged, initialFlagged, "第二次應恢復原狀")
    }
    
    // 測試：勝利條件判斷
    func testCheckWin_Success() throws {
        // 模擬所有非地雷格已翻開
        for r in 0..<viewModel.rows {
            for c in 0..<viewModel.columns {
                if !viewModel.board[r][c].isMine {
                    viewModel.board[r][c].isRevealed = true
                }
            }
        }
        

    }
    
    func testCheckWin_NotYet() throws {
        // 只翻開部分格子
        viewModel.board[0][0].isRevealed = true
        
    }
    
    // 測試：踩到地雷
    func testReveal_Mine() throws {
        // 強制把 (0,0) 設成地雷
        viewModel.board[0][0].isMine = true
        
        viewModel.reveal(row: 0, col: 0)
        
        XCTAssertTrue(viewModel.gameOver, "踩地雷應結束遊戲")
        XCTAssertFalse(viewModel.isWin, "踩地雷不應勝利")
        XCTAssertTrue(viewModel.message.contains("踩到地雷"), "訊息應包含踩雷")
        XCTAssertTrue(viewModel.board[0][0].isRevealed, "地雷格應翻開")
    }
    
    // 測試：自動展開空白區域 (floodFill)
    func testFloodFill() throws {
        // 模擬中間大片空白區域
        for r in 1..<5 {
            for c in 1..<5 {
                viewModel.board[r][c].neighborMines = 0  // 設成空白
                viewModel.board[r][c].isMine = false
            }
        }
        
        viewModel.reveal(row: 3, col: 3)  // 點擊中間空白
        
        // 檢查周圍空白是否全部翻開
        for r in 1..<5 {
            for c in 1..<5 {
                XCTAssertTrue(viewModel.board[r][c].isRevealed, "空白區域應自動翻開")
            }
        }
    }
    
    // 測試：新遊戲重置狀態
    func testStartNewGame_ResetsState() throws {
        // 先模擬玩到一半
        viewModel.board[0][0].isRevealed = true
        viewModel.gameOver = true
        viewModel.elapsedTime = 100
        
        viewModel.startNewGame()
        
        XCTAssertFalse(viewModel.gameOver, "新遊戲應重置 gameOver")
        XCTAssertFalse(viewModel.isWin, "新遊戲應重置 isWin")
        XCTAssertEqual(viewModel.elapsedTime, 0, "新遊戲應重置時間")
        XCTAssertEqual(viewModel.message, "", "新遊戲應清空訊息")
    }
}

