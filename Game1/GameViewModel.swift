import Foundation

struct LineClearEffect: Identifiable, Equatable {
    let id = UUID()
    let points: Int
    let lines: Int
}

@MainActor
final class GameViewModel: ObservableObject {
    private enum SettingsKeys {
        static let timeoutEnabled = "timeout_enabled"
        static let timeoutSeconds = "timeout_seconds"
    }

    @Published private(set) var snapshot: GameSnapshot
    @Published private(set) var lineClearEffect: LineClearEffect?
    @Published private(set) var remainingTime: Int?
    @Published private(set) var timeoutTriggered = false
    @Published private(set) var highScores: [HighScoreEntry] = HighScoreStore.shared.load()
    @Published var pendingHighScoreName = ""
    @Published private(set) var showingHighScoreEntry = false

    private var engine = TetrisEngine()
    private var timer: Timer?
    private var timeoutTimer: Timer?
    private var elapsedBeforePause: TimeInterval = 0
    private var runStartedAt: Date?

    init() {
        snapshot = engine.snapshot
        runStartedAt = .now
        restartTimer()
        restartTimeoutTimer()
    }

    deinit {
        timer?.invalidate()
        timeoutTimer?.invalidate()
    }

    func moveLeft() {
        apply(engine.moveHorizontal(-1))
    }

    func moveRight() {
        apply(engine.moveHorizontal(1))
    }

    func rotate() {
        apply(engine.rotateClockwise())
    }

    func softDrop() {
        apply(engine.softDrop())
    }

    func hardDrop() {
        apply(engine.hardDrop())
    }

    func togglePause() {
        let wasPaused = snapshot.isPaused
        engine.togglePause()
        if wasPaused {
            resumeTimeoutTracking()
        } else {
            pauseTimeoutTracking()
        }
        refresh()
        restartTimer()
        restartTimeoutTimer()
    }

    func restart() {
        engine.startNewGame()
        elapsedBeforePause = 0
        runStartedAt = .now
        timeoutTriggered = false
        showingHighScoreEntry = false
        pendingHighScoreName = ""
        refresh()
        restartTimer()
        restartTimeoutTimer()
    }

    func saveHighScore() {
        HighScoreStore.shared.save(name: pendingHighScoreName, score: snapshot.score, timeoutLabel: timeoutLabel)
        highScores = HighScoreStore.shared.load()
        showingHighScoreEntry = false
        pendingHighScoreName = ""
    }

    func dismissHighScoreEntry() {
        showingHighScoreEntry = false
        pendingHighScoreName = ""
    }

    func refreshTimeoutSettings() {
        if !timeoutEnabled {
            timeoutTriggered = false
            remainingTime = nil
            timeoutTimer?.invalidate()
            return
        }

        if !snapshot.isPaused, !snapshot.isGameOver, runStartedAt == nil {
            runStartedAt = .now
        }
        restartTimeoutTimer()
    }

    private func tick() {
        apply(engine.tick(), reschedule: true)
    }

    private func apply(_ events: [GameEvent], reschedule: Bool = false) {
        let previousLevel = snapshot.level
        let previousScore = snapshot.score
        let updatedSnapshot = engine.snapshot
        handle(events, scoreDelta: updatedSnapshot.score - previousScore)
        snapshot = updatedSnapshot

        if reschedule || snapshot.level != previousLevel {
            restartTimer()
        }

        if snapshot.isGameOver {
            timeoutTimer?.invalidate()
        }
    }

    private func refresh() {
        snapshot = engine.snapshot
    }

    private func restartTimer() {
        timer?.invalidate()
        guard !snapshot.isPaused, !snapshot.isGameOver else { return }

        timer = Timer.scheduledTimer(withTimeInterval: engine.dropInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func restartTimeoutTimer() {
        timeoutTimer?.invalidate()
        guard timeoutEnabled, !snapshot.isPaused, !snapshot.isGameOver else {
            remainingTime = timeoutEnabled ? remainingTimeForCurrentState() : nil
            return
        }

        updateRemainingTime()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRemainingTime()
            }
        }
    }

    private func updateRemainingTime() {
        guard timeoutEnabled else {
            remainingTime = nil
            return
        }

        let remaining = remainingTimeForCurrentState()
        remainingTime = remaining

        if let remaining, remaining <= 0, !snapshot.isGameOver {
            handleTimeoutReached()
        }
    }

    private func remainingTimeForCurrentState() -> Int? {
        guard timeoutEnabled else { return nil }
        let elapsed = elapsedBeforePause + activeRunElapsed
        return max(Int(ceil(Double(timeoutSeconds) - elapsed)), 0)
    }

    private var timeoutEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.timeoutEnabled)
    }

    private var timeoutSeconds: Int {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.timeoutSeconds)
        return stored == 0 ? 60 : stored
    }

    private var timeoutLabel: String {
        timeoutEnabled ? "\(timeoutSeconds) sec" : "Unlimited"
    }

    private var activeRunElapsed: TimeInterval {
        guard let runStartedAt else { return 0 }
        return Date().timeIntervalSince(runStartedAt)
    }

    private func pauseTimeoutTracking() {
        elapsedBeforePause += activeRunElapsed
        runStartedAt = nil
    }

    private func resumeTimeoutTracking() {
        guard runStartedAt == nil else { return }
        runStartedAt = .now
    }

    private func handleTimeoutReached() {
        timeoutTriggered = true
        let events = engine.forceGameOver()
        let updatedSnapshot = engine.snapshot
        handle(events, scoreDelta: 0)
        snapshot = updatedSnapshot
        timeoutTimer?.invalidate()
        remainingTime = 0

        if snapshot.score > HighScoreStore.shared.highestScore() {
            showingHighScoreEntry = true
        }
    }

    private func handle(_ events: [GameEvent], scoreDelta: Int) {
        for event in events {
            switch event {
            case .moved:
                SoundEffectPlayer.shared.play(.move)
            case .rotated:
                SoundEffectPlayer.shared.play(.rotate)
            case .hardDropped:
                SoundEffectPlayer.shared.play(.hardDrop)
            case .lineClear(let lines):
                SoundEffectPlayer.shared.play(.lineClear)
                HapticManager.shared.playLineClear(lines: lines)
                showLineClearEffect(points: max(scoreDelta, 0), lines: lines)
            case .gameOver:
                SoundEffectPlayer.shared.play(.gameOver)
            case .locked:
                break
            }
        }
    }

    private func showLineClearEffect(points: Int, lines: Int) {
        let effect = LineClearEffect(points: points, lines: lines)
        lineClearEffect = effect

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if lineClearEffect?.id == effect.id {
                lineClearEffect = nil
            }
        }
    }
}
