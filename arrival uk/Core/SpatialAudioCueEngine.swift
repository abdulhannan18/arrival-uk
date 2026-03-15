import AVFoundation
import Foundation

@MainActor
final class SpatialAudioCueEngine {
    static let shared = SpatialAudioCueEngine()

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let player = AVAudioPlayerNode()
    private var didConfigure = false

    private init() {}

    func playSettledMilestoneCue() {
        configureIfNeeded()
        guard engine.isRunning else { return }
        guard let cueBuffer = makeCueBuffer() else { return }

        player.position = AVAudio3DPoint(x: 0, y: 0, z: -0.25)
        player.renderingAlgorithm = .HRTFHQ

        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(cueBuffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        #if canImport(UIKit)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            CrashReporter.record(error: error, context: "phase12_spatial_audio_session")
        }
        #endif

        engine.attach(environment)
        engine.attach(player)

        let format = engine.outputNode.outputFormat(forBus: 0)
        environment.outputType = .headphones
        engine.connect(player, to: environment, format: format)
        engine.connect(environment, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            CrashReporter.record(error: error, context: "phase12_spatial_audio_engine_start")
        }
    }

    private func makeCueBuffer() -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * 0.18)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return nil
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?.pointee else { return nil }

        let frequency = 780.0
        for frameIndex in 0 ..< Int(frameCount) {
            let progress = Double(frameIndex) / Double(frameCount)
            let envelope = max(0, 1 - progress)
            let t = Double(frameIndex) / sampleRate
            let sine = sin(2 * .pi * frequency * t)
            let sparkle = Double.random(in: -0.16 ... 0.16)
            channel[frameIndex] = Float((sine * 0.25 + sparkle) * envelope)
        }
        return buffer
    }
}
