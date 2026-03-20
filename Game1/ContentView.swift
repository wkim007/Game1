import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @AppStorage("sound_enabled") private var soundEnabled = true
    @AppStorage("show_next_piece") private var showNextPiece = true
    @State private var showingSettings = false

    var body: some View {
        gameView
            .overlay {
                if showingSettings {
                    settingsOverlay
                }
            }
    }

    private var gameView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.15, blue: 0.18), Color(red: 0.08, green: 0.22, blue: 0.33)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    topPanel

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 0.16, green: 0.27, blue: 0.35))
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 8) {
                    leftSidebar

                    BoardView(board: viewModel.snapshot.board)
                        .overlay(alignment: .center) {
                            overlayText
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    rightSidebar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                controls
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
    }

    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    showingSettings = false
                }

            SettingsView(
                soundEnabled: $soundEnabled,
                showNextPiece: $showNextPiece,
                onClose: { showingSettings = false }
            )
            .frame(maxWidth: 340)
            .padding(24)
        }
        .transition(.opacity)
    }

    private var leftSidebar: some View {
        VStack(spacing: 10) {
            Spacer()
            IconControlButton(systemImage: viewModel.snapshot.isPaused ? "play.fill" : "pause.fill", width: 46, height: 46) {
                viewModel.togglePause()
            }
            IconControlButton(systemImage: "gobackward", width: 46, height: 46) {
                viewModel.restart()
            }
            if showNextPiece {
                NextPieceView(kind: viewModel.snapshot.nextPiece)
            }
            Spacer()
        }
        .frame(width: 52)
    }

    private var rightSidebar: some View {
        Spacer()
            .frame(width: 8)
    }

    private var topPanel: some View {
        HStack(spacing: 8) {
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
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                IconControlButton(systemImage: "arrow.left", width: 56, height: 46) {
                    viewModel.moveLeft()
                }
                IconControlButton(systemImage: "rotate.right", width: 56, height: 46) {
                    viewModel.rotate()
                }
                IconControlButton(systemImage: "arrow.right", width: 56, height: 46) {
                    viewModel.moveRight()
                }
            }

            HStack(spacing: 8) {
                Spacer()
                    .frame(width: 64)
                IconControlButton(systemImage: "arrow.down.to.line", width: 56, height: 46) {
                    viewModel.hardDrop()
                }
                Spacer()
                    .frame(width: 64)
            }
        }
        .padding(.top, 18)
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

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                        .shadow(color: .black.opacity(0.28), radius: 20, y: 14)

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

                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
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
        VStack(spacing: 5) {
            Text("Next")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))

            VStack(spacing: 2) {
                let cells = kind.previewGrid
                ForEach(cells.indices, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(cells[row].indices, id: \.self) { column in
                            if cells[row][column] {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(kind.fillColor)
                                    .frame(width: 8, height: 8)
                            } else {
                                Color.clear
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 44)
    }
}

private struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct IconControlButton: View {
    let systemImage: String
    var width: CGFloat = 64
    var height: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .frame(width: width, height: height)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.27, blue: 0.35))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsView: View {
    @Binding var soundEnabled: Bool
    @Binding var showNextPiece: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("Settings")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: $soundEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sound Effects")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .tint(Color(red: 0.29, green: 0.56, blue: 0.8))
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Toggle(isOn: $showNextPiece) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Show Next")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .tint(Color(red: 0.29, green: 0.56, blue: 0.8))
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.13, blue: 0.16), Color(red: 0.08, green: 0.18, blue: 0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 16)
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
