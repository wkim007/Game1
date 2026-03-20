import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @AppStorage("sound_enabled") private var soundEnabled = true
    @AppStorage("vibration_enabled") private var vibrationEnabled = true
    @AppStorage("show_next_piece") private var showNextPiece = true
    @AppStorage("timeout_enabled") private var timeoutEnabled = false
    @AppStorage("timeout_seconds") private var timeoutSeconds = 60
    @AppStorage("manual_level_enabled") private var manualLevelEnabled = false
    @AppStorage("manual_level_value") private var manualLevelValue = 1
    @State private var showingSettings = false
    @State private var showingRanks = false
    @State private var showingResetRanksConfirmation = false

    var body: some View {
        gameView
            .onChange(of: timeoutEnabled) { _, _ in
                viewModel.refreshTimeoutSettings()
            }
            .onChange(of: timeoutSeconds) { _, _ in
                viewModel.refreshTimeoutSettings()
            }
            .onChange(of: manualLevelEnabled) { _, _ in
                if manualLevelEnabled {
                    manualLevelValue = 1
                }
                viewModel.refreshGameplaySettings()
            }
            .onChange(of: manualLevelValue) { _, _ in
                viewModel.refreshGameplaySettings()
            }
            .overlay {
                ZStack {
                    if showingSettings {
                        settingsOverlay
                    }
                    if showingRanks {
                        rankOverlay
                    }
                    if showingResetRanksConfirmation {
                        resetRanksOverlay
                    }
                    if viewModel.showingHighScoreEntry {
                        highScoreOverlay
                    }
                    if viewModel.showingHighScoreCelebration {
                        highScoreCelebrationOverlay
                    }
                }
            }
    }

    private var gameView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color(red: 0.11, green: 0.08, blue: 0.18)],
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
                                    .fill(Color(red: 0.18, green: 0.16, blue: 0.27))
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
                        .overlay(alignment: .top) {
                            lineClearOverlay
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
        popupOverlay {
            SettingsView(
                soundEnabled: $soundEnabled,
                vibrationEnabled: $vibrationEnabled,
                showNextPiece: $showNextPiece,
                timeoutEnabled: $timeoutEnabled,
                timeoutSeconds: $timeoutSeconds,
                manualLevelEnabled: $manualLevelEnabled,
                manualLevelValue: $manualLevelValue,
                onResetRanks: { showingResetRanksConfirmation = true },
                onClose: { showingSettings = false }
            )
        } backgroundTap: {
            showingSettings = false
        }
    }

    private var rankOverlay: some View {
        popupOverlay {
            RankView(entries: viewModel.highScores, onClose: { showingRanks = false })
        } backgroundTap: {
            showingRanks = false
        }
    }

    private var resetRanksOverlay: some View {
        popupOverlay {
            ConfirmationView(
                title: "Reset Rank",
                message: "Are you sure you want to delete all saved rank records?",
                confirmTitle: "OK",
                cancelTitle: "Cancel",
                onConfirm: {
                    viewModel.resetHighScores()
                    showingResetRanksConfirmation = false
                    showingSettings = false
                    showingRanks = false
                },
                onCancel: { showingResetRanksConfirmation = false }
            )
        } backgroundTap: {
            showingResetRanksConfirmation = false
        }
    }

    private var highScoreOverlay: some View {
        popupOverlay {
            HighScoreEntryView(
                name: $viewModel.pendingHighScoreName,
                score: viewModel.snapshot.score,
                onSave: { viewModel.saveHighScore() },
                onClose: { viewModel.dismissHighScoreEntry() }
            )
        } backgroundTap: {}
    }

    private var highScoreCelebrationOverlay: some View {
        VStack {
            FlashCongratulationsView()
                .padding(.top, 84)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var leftSidebar: some View {
        VStack(spacing: 10) {
            Spacer()
            IconControlButton(systemImage: "list.number", width: 46, height: 46) {
                showingRanks = true
            }
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
            MetricCard(label: "Score", value: "\(viewModel.snapshot.score)", isHighlighted: viewModel.timeoutTriggered)
            MetricCard(label: "Lines", value: "\(viewModel.snapshot.lines)")
            MetricCard(label: "Level", value: "\(viewModel.snapshot.level)")
            if timeoutEnabled {
                MetricCard(label: "Time", value: timeText)
            }
        }
    }

    private var timeText: String {
        guard let remaining = viewModel.remainingTime else { return "--" }
        return "\(remaining)s"
    }

    private var overlayText: some View {
        Group {
            if !viewModel.hasStarted {
                startGameCard
            } else if viewModel.timeoutTriggered {
                messageCard(title: "Time Up", subtitle: "Final score locked")
            } else if viewModel.snapshot.isGameOver {
                messageCard(title: "Game Over", subtitle: "Tap Restart to play again")
            } else if viewModel.snapshot.isPaused {
                messageCard(title: "Paused", subtitle: "Resume when ready")
            }
        }
    }

    private var startGameCard: some View {
        VStack(spacing: 14) {
            Text("Ready")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Button(action: { viewModel.startGame() }) {
                Text("Start Game")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.34, green: 0.62, blue: 0.92), Color(red: 0.2, green: 0.38, blue: 0.65)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.34, green: 0.62, blue: 0.92).opacity(0.28), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var lineClearOverlay: some View {
        Group {
            if let effect = viewModel.lineClearEffect {
                LineClearEffectView(effect: effect)
                    .padding(.top, 18)
                    .transition(.asymmetric(
                        insertion: .offset(y: 6).combined(with: .opacity),
                        removal: .offset(y: -24).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.lineClearEffect)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                IconControlButton(systemImage: "arrow.left", width: 70, height: 58) {
                    viewModel.moveLeft()
                }
                IconControlButton(systemImage: "rotate.right", width: 70, height: 58) {
                    viewModel.rotate()
                }
                IconControlButton(systemImage: "arrow.right", width: 70, height: 58) {
                    viewModel.moveRight()
                }
            }

            HStack(spacing: 14) {
                Spacer()
                    .frame(width: 84)
                IconControlButton(systemImage: "arrow.down.to.line", width: 70, height: 58) {
                    viewModel.hardDrop()
                }
                Spacer()
                    .frame(width: 84)
            }
        }
        .padding(.top, 24)
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

    private func popupOverlay<Popup: View>(
        @ViewBuilder content: () -> Popup,
        backgroundTap: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: backgroundTap)

            content()
                .frame(maxWidth: 340)
                .padding(24)
        }
        .transition(.opacity)
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
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.16, green: 0.12, blue: 0.25), Color(red: 0.09, green: 0.08, blue: 0.16)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 16)

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: boardWidth * 0.36)
                        .blur(radius: 26)
                        .offset(y: -boardHeight * 0.18)

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
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(kind == nil ? Color(red: 0.17, green: 0.19, blue: 0.25) : kind!.fillColor)

            if let kind {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(kind.shadowColor, lineWidth: 1.2)

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.34), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 4)
                    Spacer(minLength: 0)
                }
                .padding(1)

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 3)
                    Spacer(minLength: 0)
                }
                .padding(1)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(kind.shadowColor.opacity(0.9))
                        .frame(height: 3)
                }
                .padding(1)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(kind.shadowColor.opacity(0.9))
                        .frame(width: 3)
                }
                .padding(1)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            }
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
    var isHighlighted = false

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
        .background(
            (isHighlighted ? Color(red: 0.52, green: 0.18, blue: 0.18).opacity(0.9) : Color.white.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isHighlighted ? Color(red: 1.0, green: 0.73, blue: 0.28) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct LineClearEffectView: View {
    let effect: LineClearEffect

    var body: some View {
        VStack(spacing: 2) {
            Text("+\(effect.points)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.3))

            Text(effect.lines == 4 ? "TETRIS" : "LINE CLEAR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.3, green: 0.18, blue: 0.42), Color(red: 0.16, green: 0.1, blue: 0.23)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.22).opacity(0.22), radius: 12, y: 4)
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
        }
        .buttonStyle(ArcadeControlButtonStyle(width: width, height: height))
    }
}

private struct ArcadeControlButtonStyle: ButtonStyle {
    let width: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color(red: 1.0, green: 0.9, blue: 0.42) : .white)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: configuration.isPressed
                                ? [
                                    Color(red: 1.0, green: 0.82, blue: 0.3).opacity(0.42),
                                    Color(red: 1.0, green: 0.82, blue: 0.3).opacity(0.12),
                                    .clear
                                ]
                                : [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    .clear
                                ],
                            center: .center,
                            startRadius: 6,
                            endRadius: max(width, height) * 0.85
                        )
                    )
                    .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
                    .blur(radius: configuration.isPressed ? 10 : 2)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color(red: 0.4, green: 0.28, blue: 0.12), Color(red: 0.22, green: 0.16, blue: 0.06)]
                                : [Color(red: 0.26, green: 0.2, blue: 0.36), Color(red: 0.15, green: 0.14, blue: 0.23)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(configuration.isPressed ? Color(red: 1.0, green: 0.82, blue: 0.24) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: configuration.isPressed
                    ? Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.34)
                    : .black.opacity(0.22),
                radius: configuration.isPressed ? 16 : 14,
                y: configuration.isPressed ? 1 : 6
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .frame(width: width, height: height)
    }
}

private struct SettingsView: View {
    @Binding var soundEnabled: Bool
    @Binding var vibrationEnabled: Bool
    @Binding var showNextPiece: Bool
    @Binding var timeoutEnabled: Bool
    @Binding var timeoutSeconds: Int
    @Binding var manualLevelEnabled: Bool
    @Binding var manualLevelValue: Int
    let onResetRanks: () -> Void
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

            Toggle(isOn: $vibrationEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vibration")
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

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $timeoutEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeout")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(timeoutEnabled ? "\(timeoutSeconds) sec" : "Unlimited")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .tint(Color(red: 0.29, green: 0.56, blue: 0.8))

                if timeoutEnabled {
                    HStack(spacing: 12) {
                        Text("10")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))

                        Slider(
                            value: Binding(
                                get: { Double(timeoutSeconds) },
                                set: { timeoutSeconds = Int($0.rounded()) }
                            ),
                            in: 10...300,
                            step: 10
                        )
                        .tint(Color(red: 0.29, green: 0.56, blue: 0.8))

                        Text("300")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $manualLevelEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(manualLevelEnabled ? "Start at \(manualLevelValue)" : "Auto leveling")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .tint(Color(red: 0.29, green: 0.56, blue: 0.8))

                if manualLevelEnabled {
                    HStack(spacing: 12) {
                        Text("1")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))

                        Slider(
                            value: Binding(
                                get: { Double(manualLevelValue) },
                                set: { manualLevelValue = Int($0.rounded()) }
                            ),
                            in: 1...100,
                            step: 1
                        )
                        .tint(Color(red: 0.29, green: 0.56, blue: 0.8))

                        Text("100")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button(action: onResetRanks) {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset Rank")
                }
                .font(.system(size: 18, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.52, green: 0.18, blue: 0.18))
                )
            }
            .buttonStyle(.plain)
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

private struct ConfirmationView: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.52, green: 0.18, blue: 0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
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
    }
}

private struct RankView: View {
    let entries: [HighScoreEntry]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top 10")
                    .font(.system(size: 30, weight: .black, design: .rounded))
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

            if entries.isEmpty {
                Text("No scores saved yet.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.68))
                                .frame(width: 26, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(Self.dateFormatter.string(from: entry.date))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.62))
                                Text(entry.timeoutLabel)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.56, green: 0.8, blue: 1.0))
                                Text(entry.levelLabel)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.3))
                            }
                            Spacer()
                            Text("\(entry.score)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.3))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
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
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HighScoreEntryView: View {
    @Binding var name: String
    let score: Int
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New High Score")
                    .font(.system(size: 28, weight: .black, design: .rounded))
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

            Text("Score: \(score)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.3))

            TextField("Enter name", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)

            Button(action: onSave) {
                Text("Save Score")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.29, green: 0.56, blue: 0.8))
                    )
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
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
    }
}

private struct FlashCongratulationsView: View {
    @State private var flash = false

    var body: some View {
        VStack(spacing: 6) {
            Text("CONGRATULATIONS!")
                .font(.system(size: 24, weight: .black, design: .rounded))
            Text("NEW HIGHEST SCORE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(flash ? Color(red: 1.0, green: 0.92, blue: 0.35) : .white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: flash
                    ? [Color(red: 0.8, green: 0.25, blue: 0.25), Color(red: 0.45, green: 0.12, blue: 0.45)]
                    : [Color(red: 0.28, green: 0.16, blue: 0.42), Color(red: 0.14, green: 0.08, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.22).opacity(0.35), radius: 18, y: 6)
        .scaleEffect(flash ? 1.04 : 0.98)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.24).repeatForever(autoreverses: true)) {
                flash = true
            }
        }
    }
}

private extension BlockKind {
    var fillColor: Color {
        switch self {
        case .i:
            return Color(red: 0.43, green: 0.9, blue: 0.93)
        case .o:
            return Color(red: 0.98, green: 0.84, blue: 0.28)
        case .t:
            return Color(red: 0.58, green: 0.4, blue: 0.95)
        case .s:
            return Color(red: 0.48, green: 0.86, blue: 0.34)
        case .z:
            return Color(red: 0.88, green: 0.3, blue: 0.25)
        case .j:
            return Color(red: 0.23, green: 0.47, blue: 0.93)
        case .l:
            return Color(red: 0.96, green: 0.52, blue: 0.2)
        }
    }

    var shadowColor: Color {
        switch self {
        case .i:
            return Color(red: 0.09, green: 0.44, blue: 0.55)
        case .o:
            return Color(red: 0.68, green: 0.5, blue: 0.1)
        case .t:
            return Color(red: 0.3, green: 0.2, blue: 0.58)
        case .s:
            return Color(red: 0.18, green: 0.47, blue: 0.13)
        case .z:
            return Color(red: 0.55, green: 0.14, blue: 0.12)
        case .j:
            return Color(red: 0.08, green: 0.2, blue: 0.56)
        case .l:
            return Color(red: 0.58, green: 0.28, blue: 0.08)
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
