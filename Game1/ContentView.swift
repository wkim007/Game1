import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.88, blue: 0.72), Color(red: 0.73, green: 0.82, blue: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                title
                scorePanel

                BoardView(board: viewModel.snapshot.board)
                    .overlay(alignment: .center) {
                        overlayText
                    }

                NextPieceView(kind: viewModel.snapshot.nextPiece)

                controls
            }
            .padding(20)
        }
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text("TETRIS")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.13, green: 0.16, blue: 0.22))
            Text("Classic falling blocks with built-in synth effects")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.65))
        }
    }

    private var scorePanel: some View {
        HStack(spacing: 12) {
            MetricCard(label: "Score", value: "\(viewModel.snapshot.score)")
            MetricCard(label: "Lines", value: "\(viewModel.snapshot.lines)")
            MetricCard(label: "Level", value: "\(viewModel.snapshot.level)")
        }
    }

    private var overlayText: some View {
        Group {
            if viewModel.snapshot.isGameOver {
                messageCard(title: "Game Over", subtitle: "Tap Restart to play again")
            } else if viewModel.snapshot.isPaused {
                messageCard(title: "Paused", subtitle: "Resume when ready")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ControlButton(title: "Left", systemImage: "arrow.left") {
                    viewModel.moveLeft()
                }
                ControlButton(title: "Rotate", systemImage: "rotate.right") {
                    viewModel.rotate()
                }
                ControlButton(title: "Right", systemImage: "arrow.right") {
                    viewModel.moveRight()
                }
            }

            HStack(spacing: 12) {
                ControlButton(title: "Down", systemImage: "arrow.down") {
                    viewModel.softDrop()
                }
                ControlButton(title: "Drop", systemImage: "arrow.down.to.line") {
                    viewModel.hardDrop()
                }
            }

            HStack(spacing: 12) {
                ControlButton(
                    title: viewModel.snapshot.isPaused ? "Resume" : "Pause",
                    systemImage: viewModel.snapshot.isPaused ? "play.fill" : "pause.fill"
                ) {
                    viewModel.togglePause()
                }
                ControlButton(title: "Restart", systemImage: "gobackward") {
                    viewModel.restart()
                }
            }
        }
    }

    private func messageCard(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(subtitle)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BoardView: View {
    let board: [[BlockKind?]]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cellSize = min(size.width / CGFloat(TetrisEngine.columns), size.height / CGFloat(TetrisEngine.rows))
            let boardWidth = cellSize * CGFloat(TetrisEngine.columns)
            let boardHeight = cellSize * CGFloat(TetrisEngine.rows)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 14)

                VStack(spacing: 2) {
                    ForEach(board.indices, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(board[row].indices, id: \.self) { column in
                                CellView(kind: board[row][column])
                                    .frame(width: cellSize - 2, height: cellSize - 2)
                            }
                        }
                    }
                }
                .frame(width: boardWidth, height: boardHeight)
                .padding(10)
            }
            .frame(width: boardWidth + 20, height: boardHeight + 20)
            .position(x: size.width / 2, y: size.height / 2)
        }
        .aspectRatio(0.56, contentMode: .fit)
    }
}

private struct CellView: View {
    let kind: BlockKind?

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(kind?.fillColor ?? Color.white.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(kind == nil ? 0.04 : 0.18), lineWidth: 1)
            }
    }
}

private struct NextPieceView: View {
    let kind: BlockKind

    var body: some View {
        VStack(spacing: 10) {
            Text("Next")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.75))

            VStack(spacing: 4) {
                let cells = kind.previewGrid
                ForEach(cells.indices, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(cells[row].indices, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(cells[row][column] ? kind.fillColor : Color.white.opacity(0.2))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.55))
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.27, blue: 0.35))
                )
        }
        .buttonStyle(.plain)
    }
}

private extension BlockKind {
    var fillColor: Color {
        switch self {
        case .i:
            return Color(red: 0.19, green: 0.74, blue: 0.84)
        case .o:
            return Color(red: 0.95, green: 0.78, blue: 0.2)
        case .t:
            return Color(red: 0.82, green: 0.35, blue: 0.23)
        case .s:
            return Color(red: 0.34, green: 0.71, blue: 0.36)
        case .z:
            return Color(red: 0.86, green: 0.29, blue: 0.23)
        case .j:
            return Color(red: 0.27, green: 0.47, blue: 0.84)
        case .l:
            return Color(red: 0.92, green: 0.52, blue: 0.14)
        }
    }

    var previewGrid: [[Bool]] {
        var grid = Array(repeating: Array(repeating: false, count: 4), count: 4)
        for (row, column) in rotations[0] {
            guard row < 4, column < 4 else { continue }
            grid[row][column] = true
        }
        return grid
    }
}
