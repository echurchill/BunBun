import AVFAudio
import Foundation

enum AudioPreferences {
    static let mutedKey = "audio.muted"
    static let musicVolumeKey = "audio.musicVolume"
    static let effectsVolumeKey = "audio.effectsVolume"

    static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: mutedKey)
    }

    static var musicVolume: Float {
        storedVolume(forKey: musicVolumeKey, defaultValue: 0.68)
    }

    static var effectsVolume: Float {
        storedVolume(forKey: effectsVolumeKey, defaultValue: 0.82)
    }

    private static func storedVolume(forKey key: String, defaultValue: Float) -> Float {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return min(1, max(0, Float(defaults.double(forKey: key))))
    }
}

enum AudioCue: CaseIterable, Hashable, Sendable {
    case launch
    case blocked
    case match
    case chain
    case bomb
    case line
    case hop
    case rescue
    case dance
    case win
    case lose

    fileprivate var resourceName: String {
        switch self {
        case .launch: "SFXLaunch"
        case .blocked: "SFXBlocked"
        case .match: "SFXMatch"
        case .chain: "SFXChain"
        case .bomb: "SFXBomb"
        case .line: "SFXLine"
        case .hop: "SFXHop"
        case .rescue: "SFXRescue"
        case .dance: "SFXDance"
        case .win: "SFXWin"
        case .lose: "SFXLose"
        }
    }

    fileprivate var gain: Float {
        switch self {
        case .launch: 0.56
        case .blocked: 0.62
        case .match: 0.72
        case .chain: 0.78
        case .bomb: 0.88
        case .line: 0.80
        case .hop: 0.48
        case .rescue: 0.76
        case .dance: 0.86
        case .win: 0.92
        case .lose: 0.70
        }
    }
}

/// Presentation-only adaptive audio. The four loop files share the same length,
/// tempo, and start time, so changing their volumes never restarts the groove.
final class AudioDirector: @unchecked Sendable {
    private enum MusicLayer: String, CaseIterable, Sendable {
        case base = "MusicBase"
        case melody = "MusicMelody"
        case pressure = "MusicPressure"
        case dance = "MusicDance"
    }

    private var musicPlayers: [MusicLayer: AVAudioPlayer] = [:]
    private var effectPlayers: [AudioCue: AVAudioPlayer] = [:]
    private var hasStartedMusic = false
    private var dangerFraction: Float = 0
    private var danceIsActive = false
    private let audioQueue = DispatchQueue(label: "com.eddie.BunBun.audio", qos: .userInitiated)
    private let audioQueueKey = DispatchSpecificKey<Void>()

    init() {
        audioQueue.setSpecific(key: audioQueueKey, value: ())
        audioQueue.async { [weak self] in
            self?.configureAudioSession()
        }
    }

    deinit {
        if DispatchQueue.getSpecific(key: audioQueueKey) != nil {
            stopOnAudioQueue()
        } else {
            audioQueue.sync {
                stopOnAudioQueue()
            }
        }
    }

    func startMusic() {
        audioQueue.async { [weak self] in
            self?.startMusicOnAudioQueue()
        }
    }

    func stop() {
        audioQueue.async { [weak self] in
            self?.stopOnAudioQueue()
        }
    }

    func setPaused(_ paused: Bool) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            if paused {
                for player in musicPlayers.values { player.pause() }
            } else {
                for player in musicPlayers.values where !player.isPlaying { player.play() }
            }
        }
    }

    func updateMix(danger: Float, danceActive: Bool, fadeDuration: TimeInterval = 0.45) {
        audioQueue.async { [weak self] in
            self?.updateMixOnAudioQueue(
                danger: danger,
                danceActive: danceActive,
                fadeDuration: fadeDuration
            )
        }
    }

    func play(_ cue: AudioCue, emphasis: Int = 0) {
        audioQueue.async { [weak self] in
            self?.playOnAudioQueue(cue, emphasis: emphasis)
        }
    }

    private func startMusicOnAudioQueue() {
        preloadEffects()
        guard !hasStartedMusic, !AudioPreferences.isMuted, AudioPreferences.musicVolume > 0 else { return }

        var loaded: [MusicLayer: AVAudioPlayer] = [:]
        for layer in MusicLayer.allCases {
            guard let player = makePlayer(named: layer.rawValue) else { continue }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            loaded[layer] = player
        }
        guard let clock = loaded[.base], !loaded.isEmpty else { return }

        musicPlayers = loaded
        hasStartedMusic = true
        let synchronizedStart = clock.deviceCurrentTime + 0.12
        for player in loaded.values {
            player.play(atTime: synchronizedStart)
        }
        updateMixOnAudioQueue(danger: dangerFraction, danceActive: danceIsActive, fadeDuration: 0.65)
    }

    private func stopOnAudioQueue() {
        for player in musicPlayers.values { player.stop() }
        for player in effectPlayers.values { player.stop() }
        musicPlayers.removeAll()
        effectPlayers.removeAll()
        hasStartedMusic = false
    }

    private func updateMixOnAudioQueue(
        danger: Float,
        danceActive: Bool,
        fadeDuration: TimeInterval
    ) {
        dangerFraction = min(1, max(0, danger))
        danceIsActive = danceActive
        guard hasStartedMusic else {
            startMusicOnAudioQueue()
            return
        }

        let master = AudioPreferences.isMuted ? 0 : AudioPreferences.musicVolume
        let pressureCurve = pow(dangerFraction, 1.35)
        // A dance party should sound like a new section, not one more quiet
        // ornament on top of the normal arrangement. Duck the familiar hook
        // and remove the danger pulse so the brighter dance stem owns the mix.
        setVolume((danceActive ? 0.38 : 0.50) * master, for: .base, duration: fadeDuration)
        setVolume((danceActive ? 0.12 : 0.34) * master, for: .melody, duration: fadeDuration)
        setVolume((danceActive ? 0 : 0.025 + pressureCurve * 0.34) * master, for: .pressure, duration: fadeDuration)
        setVolume((danceActive ? 0.82 : 0) * master, for: .dance, duration: fadeDuration)
    }

    private func playOnAudioQueue(_ cue: AudioCue, emphasis: Int) {
        guard !AudioPreferences.isMuted, AudioPreferences.effectsVolume > 0 else { return }
        let player: AVAudioPlayer
        if let preloaded = effectPlayers[cue] {
            player = preloaded
        } else if let loaded = makePlayer(named: cue.resourceName) {
            player = loaded
        } else {
            return
        }
        player.volume = min(1, cue.gain * AudioPreferences.effectsVolume)
        player.enableRate = true
        player.rate = min(1.22, 1 + Float(max(0, emphasis)) * 0.045)
        player.currentTime = 0
        player.prepareToPlay()
        player.play()
        effectPlayers[cue] = player
    }

    private func setVolume(_ volume: Float, for layer: MusicLayer, duration: TimeInterval) {
        musicPlayers[layer]?.setVolume(min(1, max(0, volume)), fadeDuration: duration)
    }

    private func makePlayer(named resourceName: String) -> AVAudioPlayer? {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "wav", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "wav")
        guard let url else {
            assertionFailure("Missing audio resource: \(resourceName).wav")
            return nil
        }

        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            assertionFailure("Could not load \(resourceName).wav: \(error)")
            return nil
        }
    }

    private func preloadEffects() {
        for cue in AudioCue.allCases where effectPlayers[cue] == nil {
            guard let player = makePlayer(named: cue.resourceName) else { continue }
            player.enableRate = true
            player.prepareToPlay()
            effectPlayers[cue] = player
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } catch {
            // Audio is enhancement-only; a session conflict must not stop play.
            print("BunBun audio session unavailable: \(error)")
        }
    }
}
