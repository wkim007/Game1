import Foundation

struct LineClearEffect: Identifiable, Equatable {
    let id = UUID()
    let points: Int
    let lines: Int
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var snapshot: GameSnapshot
    @Published private(set) var lineClearEffect: LineClearEffect?

    private var engine = TetrisEngine()
    private var timer: Timer?

    init() {
        snapshot = engine.snapshot
        restartTimer()
    }

    deinit {
        timer?.invalidate()
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
        engine.togglePause()
        refresh()
        restartTimer()
    }

    func restart() {
        engine.startNewGame()
        refresh()
        restartTimer()
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
