import AppKit
import AVFoundation

/// Mater's sounds: a ding as a phase ends, a click on pause and resume, a wind-up as one starts.
@MainActor
final class PomodoroSoundRunner {
    enum Cue {
        case ding
        case toggleOn
        case toggleOff
    }

    private static let sampleRate: Double = 44_100
    /// Mater winds its ruler at 500 points a second, at 20 points a minute.
    private static let windSecondsPerMinute: TimeInterval = 20.0 / 500.0

    private lazy var ding = Self.sound("pomodoro-ding")
    private lazy var toggleOn = Self.sound("pomodoro-toggle-on")
    private lazy var toggleOff = Self.sound("pomodoro-toggle-off")
    private lazy var tickSamples = Self.samples("pomodoro-tick")
    private var windup: AVAudioPlayer?

    func play(_ cue: Cue) {
        let sound =
            switch cue {
            case .ding: ding
            case .toggleOn: toggleOn
            case .toggleOff: toggleOff
            }
        sound?.stop()
        sound?.play()
    }

    /// One tick per minute being wound, bunched toward the end the way a spring runs down.
    func windUp(minutes: Int) {
        windup?.stop()
        let clicks = max(minutes, 1)
        let duration = max(Double(clicks) * Self.windSecondsPerMinute, 0.25)
        guard let tickSamples, let data = Self.windupWAV(clicks: clicks, duration: duration, tick: tickSamples)
        else { return }
        windup = try? AVAudioPlayer(data: data)
        windup?.play()
    }

    func stopWindUp() {
        windup?.stop()
        windup = nil
    }

    private static func sound(_ name: String) -> NSSound? {
        Bundle.main.url(forResource: name, withExtension: "wav").flatMap {
            NSSound(contentsOf: $0, byReference: false)
        }
    }

    private static func samples(_ name: String) -> [Float]? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
            let file = try? AVAudioFile(forReading: url),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
            (try? file.read(into: buffer)) != nil,
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    /// Mater's generator: ticks at `1 - sqrt(1 - t)` with a seeded random loudness, as 16-bit mono.
    private static func windupWAV(clicks: Int, duration: TimeInterval, tick: [Float]) -> Data? {
        let frameCount = Int(duration * sampleRate)
        guard frameCount > 0 else { return nil }
        var mix = [Float](repeating: 0, count: frameCount)
        var seed: UInt64 = 12_345
        for index in 0..<clicks {
            let position = clicks > 1 ? Double(index) / Double(clicks - 1) : 0
            let start = Int((1 - (1 - position).squareRoot()) * max(duration - 0.01, 0) * sampleRate)
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let loudness = 0.5 + abs(Float(Int64(bitPattern: seed >> 33)) / Float(Int64.max >> 33)) * 0.5
            for (offset, sample) in tick.enumerated() where start + offset < frameCount {
                mix[start + offset] += sample * loudness
            }
        }
        return wav(mix)
    }

    private static func wav(_ samples: [Float]) -> Data {
        let dataSize = samples.count * 2
        var data = Data(capacity: 44 + dataSize)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return data
    }
}
