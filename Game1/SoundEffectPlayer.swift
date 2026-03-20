import AVFoundation
import Foundation

final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()
    private static let soundEnabledKey = "sound_enabled"

    enum Effect {
        case move
        case rotate
        case hardDrop
        case lineClear
        case gameOver
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.soundEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.soundEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.soundEnabledKey)
        }
    }

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            assertionFailure("Audio session setup failed: \(error)")
        }
        #endif

        do {
            try engine.start()
            player.play()
        } catch {
            assertionFailure("Audio engine failed to start: \(error)")
        }
    }

    func play(_ effect: Effect) {
        guard isEnabled else { return }

        let sequence: [(Double, Double, Double)]
        switch effect {
        case .move:
            sequence = [(540, 0.045, 0.16)]
        case .rotate:
            sequence = [(660, 0.04, 0.18), (880, 0.05, 0.14)]
        case .hardDrop:
            sequence = [(240, 0.06, 0.22), (180, 0.08, 0.18)]
        case .lineClear:
            sequence = [(740, 0.06, 0.18), (880, 0.06, 0.18), (1040, 0.08, 0.16)]
        case .gameOver:
            sequence = [(340, 0.08, 0.18), (280, 0.1, 0.18), (220, 0.12, 0.18)]
        }

        player.scheduleBuffer(makeBuffer(sequence), at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }

    private func makeBuffer(_ sequence: [(Double, Double, Double)]) -> AVAudioPCMBuffer {
        let frameCapacity = sequence.reduce(0) { partial, segment in
            partial + Int(segment.1 * format.sampleRate)
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCapacity))!
        buffer.frameLength = buffer.frameCapacity

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        var sampleIndex = 0
        for (frequency, duration, amplitude) in sequence {
            let frameCount = Int(duration * format.sampleRate)
            for frame in 0..<frameCount {
                let progress = Double(frame) / Double(max(frameCount, 1))
                let envelope = (1.0 - progress) * amplitude
                let time = Double(sampleIndex) / format.sampleRate
                channel[sampleIndex] = Float(sin(2.0 * .pi * frequency * time) * envelope)
                sampleIndex += 1
            }
        }

        return buffer
    }
}
