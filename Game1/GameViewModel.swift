import Foundation

struct LineClearEffect: Identifiable, Equatable {
    let id = UUID()
    let points: Int
    let lines: Int
    let bonusPoints: Int
    let specialKinds: [SpecialBlockKind]
}

@MainActor
final class GameViewModel: ObservableObject {
    private enum SettingsKeys {
        static let timeoutEnabled = "timeout_enabled"
        static let timeoutSeconds = "timeout_seconds"
        static let manualLevelEnabled = "manual_level_enabled"
        static let manualLevelValue = "manual_level_value"
    }

    @Published private(set) var snapshot: GameSnapshot
    @Published private(set) var lineClearEffect: LineClearEffect?
    @Published private(set) var remainingTime: Int?
    @Published private(set) var timeoutTriggered = false
    @Published private(set) var highScores: [HighScoreEntry] = HighScoreStore.shared.load()
    @Published private(set) var hasStarted = false
    @Published var pendingHighScoreName = ""
    @Published private(set) var showingHighScoreEntry = false
    @Published private(set) var showingHighScoreCelebration = false

    private var engine = TetrisEngine()
    private var timer: Timer?
    private var timeoutTimer: Timer?
    private var elapsedBeforePause: TimeInterval = 0
    private var runStartedAt: Date?

    init() {
        engine.setManualLevel(Self.initialManualLevelFromDefaults())
        snapshot = engine.snapshot
        runStartedAt = nil
        remainingTime = nil
    }

    deinit {
        timer?.invalidate()
        timeoutTimer?.invalidate()
    }

    func moveLeft() {
        guard hasStarted else { return }
        apply(engine.moveHorizontal(-1))
    }

    func moveRight() {
        guard hasStarted else { return }
        apply(engine.moveHorizontal(1))
    }

    func rotate() {
        guard hasStarted else { return }
        apply(engine.rotateClockwise())
    }

    func softDrop() {
        guard hasStarted else { return }
        apply(engine.softDrop())
    }

    func hardDrop() {
        guard hasStarted else { return }
        apply(engine.hardDrop())
    }

    func startGame() {
        guard !hasStarted else { return }
        hasStarted = true
        timeoutTriggered = false
        elapsedBeforePause = 0
        runStartedAt = .now
        refresh()
        restartTimer()
        restartTimeoutTimer()
    }

    func togglePause() {
        guard hasStarted else { return }
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
        hasStarted = true
        elapsedBeforePause = 0
        runStartedAt = .now
        timeoutTriggered = false
        showingHighScoreEntry = false
        showingHighScoreCelebration = false
        pendingHighScoreName = ""
        applyGameplaySettings()
        refresh()
        restartTimer()
        restartTimeoutTimer()
    }

    func saveHighScore() {
        HighScoreStore.shared.save(
            name: pendingHighScoreName,
            score: snapshot.score,
            timeoutLabel: timeoutLabel,
            levelLabel: "Level \(snapshot.level)"
        )
        highScores = HighScoreStore.shared.load()
        showingHighScoreEntry = false
        showingHighScoreCelebration = false
        pendingHighScoreName = ""
    }

    func dismissHighScoreEntry() {
        showingHighScoreEntry = false
        showingHighScoreCelebration = false
        pendingHighScoreName = ""
    }

    func refreshTimeoutSettings() {
        guard hasStarted else {
            timeoutTriggered = false
            remainingTime = nil
            timeoutTimer?.invalidate()
            return
        }

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

    func refreshGameplaySettings() {
        let previousLevel = snapshot.level
        applyGameplaySettings()
        refresh()

        if snapshot.level != previousLevel {
            restartTimer()
        }
    }

    func resetHighScores() {
        HighScoreStore.shared.reset()
        highScores = []
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
            evaluateHighScoreQualification()
        }
    }

    private func refresh() {
        snapshot = engine.snapshot
    }

    private func applyGameplaySettings() {
        engine.setManualLevel(manualLevelEnabled ? manualLevelValue : nil)
    }

    private func restartTimer() {
        timer?.invalidate()
        guard hasStarted, !snapshot.isPaused, !snapshot.isGameOver else { return }

        timer = Timer.scheduledTimer(withTimeInterval: engine.dropInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func restartTimeoutTimer() {
        timeoutTimer?.invalidate()
        guard hasStarted, timeoutEnabled, !snapshot.isPaused, !snapshot.isGameOver else {
            remainingTime = hasStarted && timeoutEnabled ? remainingTimeForCurrentState() : nil
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

    private var manualLevelEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.manualLevelEnabled)
    }

    private var manualLevelValue: Int {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.manualLevelValue)
        return stored == 0 ? 1 : min(max(stored, 1), 100)
    }

    private static func initialManualLevelFromDefaults() -> Int? {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: SettingsKeys.manualLevelEnabled)
        let stored = defaults.integer(forKey: SettingsKeys.manualLevelValue)
        let level = stored == 0 ? 1 : min(max(stored, 1), 100)
        return enabled ? level : nil
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
        evaluateHighScoreQualification()
    }

    private func evaluateHighScoreQualification() {
        guard snapshot.isGameOver, !showingHighScoreEntry else { return }
        guard HighScoreStore.shared.qualifiesForTopTen(score: snapshot.score) else { return }

        showingHighScoreEntry = true
        if snapshot.score > HighScoreStore.shared.highestScore() {
            triggerHighScoreCelebration()
        }
    }

    private func triggerHighScoreCelebration() {
        showingHighScoreCelebration = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if showingHighScoreEntry {
                showingHighScoreCelebration = false
            }
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
            case .lineClear(let lines, let bonuses):
                SoundEffectPlayer.shared.play(.lineClear)
                HapticManager.shared.playLineClear(lines: lines)
                showLineClearEffect(
                    points: max(scoreDelta, 0),
                    lines: lines,
                    bonusPoints: bonuses.reduce(0) { $0 + $1.points },
                    specialKinds: bonuses.map(\.kind)
                )
            case .gameOver:
                SoundEffectPlayer.shared.play(.gameOver)
            case .locked:
                break
            }
        }
    }

    private func showLineClearEffect(points: Int, lines: Int, bonusPoints: Int, specialKinds: [SpecialBlockKind]) {
        let effect = LineClearEffect(
            points: points,
            lines: lines,
            bonusPoints: bonusPoints,
            specialKinds: specialKinds
        )
        lineClearEffect = effect

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if lineClearEffect?.id == effect.id {
                lineClearEffect = nil
            }
        }
    }
}
