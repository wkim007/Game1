import Foundation

enum BlockKind: CaseIterable, Codable {
    case i
    case o
    case t
    case s
    case z
    case j
    case l
}

struct Piece {
    var kind: BlockKind
    var rotation: Int
    var row: Int
    var column: Int
    var specialKind: SpecialBlockKind?
    var specialCellIndex: Int?
}

enum SpecialBlockKind: String, CaseIterable, Codable, Equatable {
    case silver
    case gold
    case diamond

    var bonusMultiplier: Double {
        switch self {
        case .silver:
            return 0.5
        case .gold:
            return 0.8
        case .diamond:
            return 1.0
        }
    }
}

struct BoardCell: Codable, Equatable {
    let kind: BlockKind
    let specialKind: SpecialBlockKind?
}

struct SpecialClearBonus: Equatable {
    let kind: SpecialBlockKind
    let points: Int
}

enum GameEvent: Equatable {
    case moved
    case rotated
    case hardDropped
    case locked
    case lineClear(Int, [SpecialClearBonus])
    case gameOver
}

struct GameSnapshot {
    let board: [[BoardCell?]]
    let nextPiece: BlockKind
    let score: Int
    let silverCount: Int
    let goldCount: Int
    let diamondCount: Int
    let lines: Int
    let level: Int
    let isPaused: Bool
    let isGameOver: Bool
}

struct TetrisEngine {
    static let rows = 20
    static let columns = 10

    private(set) var settledBoard: [[BoardCell?]]
    private(set) var activePiece: Piece
    private(set) var nextPiece: BlockKind
    private(set) var score = 0
    private(set) var clearedLines = 0
    private(set) var silverCount = 0
    private(set) var goldCount = 0
    private(set) var diamondCount = 0
    private(set) var isPaused = false
    private(set) var isGameOver = false
    private var manualLevelOverride: Int?

    private var bag: [BlockKind] = []

    init() {
        settledBoard = Array(
            repeating: Array(repeating: nil, count: Self.columns),
            count: Self.rows
        )
        activePiece = Piece(kind: .t, rotation: 0, row: 0, column: 3, specialKind: nil, specialCellIndex: nil)
        nextPiece = .o
        startNewGame()
    }

    var level: Int {
        manualLevelOverride ?? max(1, (clearedLines / 10) + 1)
    }

    var dropInterval: TimeInterval {
        max(0.1, 0.8 - (Double(level - 1) * 0.07))
    }

    var snapshot: GameSnapshot {
        GameSnapshot(
            board: boardWithActivePiece(),
            nextPiece: nextPiece,
            score: score,
            silverCount: silverCount,
            goldCount: goldCount,
            diamondCount: diamondCount,
            lines: clearedLines,
            level: level,
            isPaused: isPaused,
            isGameOver: isGameOver
        )
    }

    mutating func startNewGame() {
        settledBoard = Array(
            repeating: Array(repeating: nil, count: Self.columns),
            count: Self.rows
        )
        score = 0
        clearedLines = 0
        silverCount = 0
        goldCount = 0
        diamondCount = 0
        isPaused = false
        isGameOver = false
        bag.removeAll()
        nextPiece = dequeueKind()
        spawnNextPiece()
    }

    mutating func togglePause() {
        guard !isGameOver else { return }
        isPaused.toggle()
    }

    mutating func tick() -> [GameEvent] {
        guard !isPaused, !isGameOver else { return [] }
        if canPlace(activePiece, rowOffset: 1, columnOffset: 0) {
            activePiece.row += 1
            return []
        }
        return lockActivePiece()
    }

    mutating func moveHorizontal(_ delta: Int) -> [GameEvent] {
        guard !isPaused, !isGameOver else { return [] }
        guard canPlace(activePiece, rowOffset: 0, columnOffset: delta) else { return [] }
        activePiece.column += delta
        return [.moved]
    }

    mutating func softDrop() -> [GameEvent] {
        guard !isPaused, !isGameOver else { return [] }
        if canPlace(activePiece, rowOffset: 1, columnOffset: 0) {
            activePiece.row += 1
            score += 1
            return [.moved]
        }
        return lockActivePiece()
    }

    mutating func hardDrop() -> [GameEvent] {
        guard !isPaused, !isGameOver else { return [] }
        var distance = 0
        while canPlace(activePiece, rowOffset: 1, columnOffset: 0) {
            activePiece.row += 1
            distance += 1
        }
        score += distance * 2
        var events: [GameEvent] = distance > 0 ? [.hardDropped] : []
        events.append(contentsOf: lockActivePiece())
        return events
    }

    mutating func rotateClockwise() -> [GameEvent] {
        guard !isPaused, !isGameOver else { return [] }
        let nextRotation = (activePiece.rotation + 1) % 4
        let kicks = [(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0), (0, -2), (0, 2)]

        for (rowKick, columnKick) in kicks {
            var candidate = activePiece
            candidate.rotation = nextRotation
            candidate.row += rowKick
            candidate.column += columnKick
            if canPlace(candidate) {
                activePiece = candidate
                return [.rotated]
            }
        }
        return []
    }

    mutating func forceGameOver() -> [GameEvent] {
        guard !isGameOver else { return [] }
        isGameOver = true
        return [.gameOver]
    }

    mutating func setManualLevel(_ level: Int?) {
        manualLevelOverride = level.map { min(max($0, 1), 100) }
    }

    private mutating func lockActivePiece() -> [GameEvent] {
        for (index, (row, column)) in occupiedCells(for: activePiece).enumerated() {
            guard (0..<Self.rows).contains(row), (0..<Self.columns).contains(column) else {
                isGameOver = true
                return [.gameOver]
            }
            settledBoard[row][column] = BoardCell(
                kind: activePiece.kind,
                specialKind: activePiece.specialCellIndex == index ? activePiece.specialKind : nil
            )
        }

        var events: [GameEvent] = [.locked]
        let clearResult = clearCompletedLines()
        let cleared = clearResult.lines
        if cleared > 0 {
            events.append(.lineClear(cleared, clearResult.bonuses))
        }
        spawnNextPiece()
        if !canPlace(activePiece) {
            isGameOver = true
            events.append(.gameOver)
        }
        return events
    }

    private mutating func clearCompletedLines() -> (lines: Int, bonuses: [SpecialClearBonus]) {
        let completedRows = settledBoard.filter { row in
            !row.contains(where: { $0 == nil })
        }
        let remainingRows = settledBoard.filter { row in
            row.contains(where: { $0 == nil })
        }
        let cleared = completedRows.count
        guard cleared > 0 else { return (0, []) }

        let emptyRows = Array(
            repeating: Array<BoardCell?>(repeating: nil, count: Self.columns),
            count: cleared
        )
        settledBoard = emptyRows + remainingRows
        clearedLines += cleared

        let lineScore: Int
        switch cleared {
        case 1:
            lineScore = 40
        case 2:
            lineScore = 100
        case 3:
            lineScore = 300
        default:
            lineScore = 1200
        }
        let baseAward = lineScore * level
        let bonuses = completedRows
            .flatMap { row in row.compactMap(\.self) }
            .compactMap { cell -> SpecialClearBonus? in
                guard let specialKind = cell.specialKind else { return nil }
                return SpecialClearBonus(
                    kind: specialKind,
                    points: Int((Double(baseAward) * specialKind.bonusMultiplier).rounded())
                )
            }
        for bonus in bonuses {
            switch bonus.kind {
            case .silver:
                silverCount += 1
            case .gold:
                goldCount += 1
            case .diamond:
                diamondCount += 1
            }
        }
        score += baseAward + bonuses.reduce(0) { $0 + $1.points }
        return (cleared, bonuses)
    }

    private mutating func spawnNextPiece() {
        let spawnedKind = nextPiece
        nextPiece = dequeueKind()
        activePiece = Piece(
            kind: spawnedKind,
            rotation: 0,
            row: 0,
            column: 3,
            specialKind: randomSpecialKind(),
            specialCellIndex: Int.random(in: 0..<4)
        )
    }

    private mutating func dequeueKind() -> BlockKind {
        if bag.isEmpty {
            bag = BlockKind.allCases.shuffled()
        }
        return bag.removeFirst()
    }

    private func boardWithActivePiece() -> [[BoardCell?]] {
        var board = settledBoard
        for (index, (row, column)) in occupiedCells(for: activePiece).enumerated() {
            guard (0..<Self.rows).contains(row), (0..<Self.columns).contains(column) else { continue }
            board[row][column] = BoardCell(
                kind: activePiece.kind,
                specialKind: activePiece.specialCellIndex == index ? activePiece.specialKind : nil
            )
        }
        return board
    }

    private func canPlace(
        _ piece: Piece,
        rowOffset: Int = 0,
        columnOffset: Int = 0
    ) -> Bool {
        let shifted = Piece(
            kind: piece.kind,
            rotation: piece.rotation,
            row: piece.row + rowOffset,
            column: piece.column + columnOffset
        )

        for (row, column) in occupiedCells(for: shifted) {
            if row < 0 || row >= Self.rows || column < 0 || column >= Self.columns {
                return false
            }
            if settledBoard[row][column] != nil {
                return false
            }
        }
        return true
    }

    private func occupiedCells(for piece: Piece) -> [(Int, Int)] {
        piece.kind.rotations[piece.rotation].map { offset in
            (piece.row + offset.0, piece.column + offset.1)
        }
    }

    private func randomSpecialKind() -> SpecialBlockKind? {
        guard Int.random(in: 0..<100) < 12 else { return nil }
        return SpecialBlockKind.allCases.randomElement()
    }
}

extension BlockKind {
    var rotations: [[(Int, Int)]] {
        switch self {
        case .i:
            return [
                [(1, 0), (1, 1), (1, 2), (1, 3)],
                [(0, 2), (1, 2), (2, 2), (3, 2)],
                [(2, 0), (2, 1), (2, 2), (2, 3)],
                [(0, 1), (1, 1), (2, 1), (3, 1)]
            ]
        case .o:
            let state = [(0, 1), (0, 2), (1, 1), (1, 2)]
            return [state, state, state, state]
        case .t:
            return [
                [(0, 1), (1, 0), (1, 1), (1, 2)],
                [(0, 1), (1, 1), (1, 2), (2, 1)],
                [(1, 0), (1, 1), (1, 2), (2, 1)],
                [(0, 1), (1, 0), (1, 1), (2, 1)]
            ]
        case .s:
            return [
                [(0, 1), (0, 2), (1, 0), (1, 1)],
                [(0, 1), (1, 1), (1, 2), (2, 2)],
                [(1, 1), (1, 2), (2, 0), (2, 1)],
                [(0, 0), (1, 0), (1, 1), (2, 1)]
            ]
        case .z:
            return [
                [(0, 0), (0, 1), (1, 1), (1, 2)],
                [(0, 2), (1, 1), (1, 2), (2, 1)],
                [(1, 0), (1, 1), (2, 1), (2, 2)],
                [(0, 1), (1, 0), (1, 1), (2, 0)]
            ]
        case .j:
            return [
                [(0, 0), (1, 0), (1, 1), (1, 2)],
                [(0, 1), (0, 2), (1, 1), (2, 1)],
                [(1, 0), (1, 1), (1, 2), (2, 2)],
                [(0, 1), (1, 1), (2, 0), (2, 1)]
            ]
        case .l:
            return [
                [(0, 2), (1, 0), (1, 1), (1, 2)],
                [(0, 1), (1, 1), (2, 1), (2, 2)],
                [(1, 0), (1, 1), (1, 2), (2, 0)],
                [(0, 0), (0, 1), (1, 1), (2, 1)]
            ]
        }
    }
}
