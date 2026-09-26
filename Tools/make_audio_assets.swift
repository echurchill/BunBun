import Foundation

private let sampleRate = 22_050
private let tempo = 116.0
private let beatDuration = 60.0 / tempo
private let barDuration = beatDuration * 4
private let musicDuration = barDuration * 16
private let twoPi = Double.pi * 2

private struct Sound {
    var samples: [Double]

    init(duration: Double) {
        samples = Array(repeating: 0, count: max(1, Int(duration * Double(sampleRate))))
    }

    mutating func add(
        start: Double,
        duration: Double,
        gain: Double,
        oscillator: (Double, Double) -> Double,
        envelope: (Double) -> Double = { progress in
            let attack = min(1, progress / 0.04)
            return attack * pow(max(0, 1 - progress), 1.8)
        }
    ) {
        let startSample = max(0, Int(start * Double(sampleRate)))
        let count = max(1, Int(duration * Double(sampleRate)))
        guard startSample < samples.count else { return }

        for offset in 0..<min(count, samples.count - startSample) {
            let time = Double(offset) / Double(sampleRate)
            let progress = Double(offset) / Double(max(count - 1, 1))
            samples[startSample + offset] += oscillator(time, progress) * envelope(progress) * gain
        }
    }

    mutating func tone(
        start: Double,
        duration: Double,
        frequency: Double,
        gain: Double,
        waveform: Waveform = .sine,
        attack: Double = 0.025,
        releasePower: Double = 1.7
    ) {
        add(
            start: start,
            duration: duration,
            gain: gain,
            oscillator: { time, _ in waveform.value(phase: twoPi * frequency * time) },
            envelope: { progress in
                let attackProgress = min(1, progress / max(attack, 0.001))
                return attackProgress * pow(max(0, 1 - progress), releasePower)
            }
        )
    }

    mutating func glide(
        start: Double,
        duration: Double,
        from startFrequency: Double,
        to endFrequency: Double,
        gain: Double,
        waveform: Waveform = .sine
    ) {
        add(start: start, duration: duration, gain: gain) { time, progress in
            let frequency = startFrequency * pow(endFrequency / startFrequency, progress)
            return waveform.value(phase: twoPi * frequency * time)
        }
    }

    mutating func noise(
        start: Double,
        duration: Double,
        gain: Double,
        seed: UInt64,
        releasePower: Double = 2.2
    ) {
        var generator = NoiseGenerator(seed: seed)
        add(
            start: start,
            duration: duration,
            gain: gain,
            oscillator: { _, _ in generator.next() },
            envelope: { pow(max(0, 1 - $0), releasePower) }
        )
    }

    mutating func normalize(peak targetPeak: Double = 0.91) {
        let peak = samples.reduce(0) { max($0, abs($1)) }
        guard peak > targetPeak else { return }
        let scale = targetPeak / peak
        for index in samples.indices { samples[index] *= scale }
    }

    func mixed(with other: Sound, gain: Double = 1) -> Sound {
        var result = self
        for index in 0..<min(result.samples.count, other.samples.count) {
            result.samples[index] += other.samples[index] * gain
        }
        return result
    }
}

private enum Waveform {
    case sine
    case triangle
    case square
    case softSquare

    func value(phase: Double) -> Double {
        switch self {
        case .sine:
            return sin(phase)
        case .triangle:
            return 2 / Double.pi * asin(sin(phase))
        case .square:
            return sin(phase) >= 0 ? 1 : -1
        case .softSquare:
            return tanh(sin(phase) * 2.3)
        }
    }
}

private struct NoiseGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xB00B1E : seed
    }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let value = Double((state >> 33) & 0x7FFF_FFFF) / Double(0x7FFF_FFFF)
        return value * 2 - 1
    }
}

private func frequency(_ midi: Int) -> Double {
    440 * pow(2, Double(midi - 69) / 12)
}

private func addKick(to sound: inout Sound, at time: Double, gain: Double = 0.72) {
    sound.add(start: time, duration: 0.25, gain: gain) { localTime, progress in
        let pitch = 112 * pow(45 / 112, progress)
        return sin(twoPi * pitch * localTime)
    }
}

private func addSnare(to sound: inout Sound, at time: Double, seed: UInt64, gain: Double = 0.34) {
    sound.noise(start: time, duration: 0.17, gain: gain, seed: seed, releasePower: 3.3)
    sound.tone(start: time, duration: 0.13, frequency: 176, gain: gain * 0.28, releasePower: 3.1)
}

private func addHat(to sound: inout Sound, at time: Double, seed: UInt64, gain: Double = 0.11) {
    sound.noise(start: time, duration: 0.055, gain: gain, seed: seed, releasePower: 5.2)
}

private func addClap(to sound: inout Sound, at time: Double, seed: UInt64, gain: Double = 0.22) {
    for offset in [0.0, 0.018, 0.037] {
        sound.noise(start: time + offset, duration: 0.12, gain: gain, seed: seed + UInt64(offset * 10_000), releasePower: 4)
    }
}

private func addChord(
    to sound: inout Sound,
    at time: Double,
    notes: [Int],
    duration: Double,
    gain: Double,
    waveform: Waveform = .softSquare
) {
    for (index, note) in notes.enumerated() {
        sound.tone(
            start: time + Double(index) * 0.004,
            duration: duration,
            frequency: frequency(note),
            gain: gain / Double(notes.count),
            waveform: waveform,
            attack: 0.035,
            releasePower: 2.0
        )
    }
}

private func makeBase() -> Sound {
    var sound = Sound(duration: musicDuration)
    let roots = [48, 45, 41, 43] // C, A, F, G
    let chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    let bassSteps = [0, 0, 7, 12, 0, 7, 10, 7]

    for bar in 0..<16 {
        let barStart = Double(bar) * barDuration
        let variation = bar % 4
        for beat in 0..<4 {
            let time = barStart + Double(beat) * beatDuration
            if beat == 0 || beat == 2 { addKick(to: &sound, at: time, gain: beat == 0 ? 0.72 : 0.60) }
            if beat == 1 || beat == 3 { addSnare(to: &sound, at: time, seed: UInt64(bar * 10 + beat)) }
            if variation == 3 && beat == 3 { addKick(to: &sound, at: time + beatDuration * 0.72, gain: 0.40) }
        }
        for eighth in 0..<8 {
            let time = barStart + Double(eighth) * beatDuration / 2
            addHat(to: &sound, at: time, seed: UInt64(1000 + bar * 20 + eighth), gain: eighth.isMultiple(of: 2) ? 0.075 : 0.12)
            let bassNote = roots[variation] + bassSteps[eighth] % 12
            sound.tone(
                start: time,
                duration: beatDuration * 0.43,
                frequency: frequency(bassNote),
                gain: 0.28,
                waveform: .softSquare,
                attack: 0.02,
                releasePower: 1.4
            )
        }
        addChord(to: &sound, at: barStart + beatDuration * 0.48, notes: chords[variation], duration: beatDuration * 0.62, gain: 0.28)
        addChord(to: &sound, at: barStart + beatDuration * 2.48, notes: chords[variation], duration: beatDuration * 0.75, gain: 0.24)
    }
    sound.normalize()
    return sound
}

private func makeMelody() -> Sound {
    var sound = Sound(duration: musicDuration)
    // Original four-bar call-and-response hook in C major.
    let hook: [[Int?]] = [
        [64, 67, 69, 67, 64, nil, 62, 64],
        [67, 72, 71, 69, 67, nil, 64, 62],
        [65, 69, 72, 69, 67, 65, 64, nil],
        [62, 67, 71, 74, 72, 71, 67, nil]
    ]

    for bar in 0..<16 {
        // Leave breathing room during the third phrase before returning to the hook.
        if bar == 8 || bar == 10 { continue }
        let barStart = Double(bar) * barDuration
        for (step, note) in hook[bar % 4].enumerated() {
            guard let note else { continue }
            let time = barStart + Double(step) * beatDuration / 2
            sound.tone(start: time, duration: beatDuration * 0.39, frequency: frequency(note + 12), gain: 0.22, waveform: .triangle, attack: 0.025, releasePower: 2.4)
            sound.tone(start: time, duration: beatDuration * 0.30, frequency: frequency(note + 24), gain: 0.055, waveform: .sine, attack: 0.02, releasePower: 2.8)
        }
    }
    sound.normalize()
    return sound
}

private func makePressure() -> Sound {
    var sound = Sound(duration: musicDuration)
    for bar in 0..<16 {
        let barStart = Double(bar) * barDuration
        for sixteenth in 0..<16 {
            let time = barStart + Double(sixteenth) * beatDuration / 4
            if sixteenth % 2 == 1 {
                addHat(to: &sound, at: time, seed: UInt64(3000 + bar * 20 + sixteenth), gain: sixteenth % 4 == 3 ? 0.13 : 0.075)
            }
        }
        for beat in 0..<4 {
            let time = barStart + Double(beat) * beatDuration
            sound.tone(start: time, duration: 0.10, frequency: frequency(72 + (bar % 4 == 3 ? 2 : 0)), gain: 0.12, waveform: .square, attack: 0.01, releasePower: 4.5)
        }
    }
    sound.normalize()
    return sound
}

private func makeDance() -> Sound {
    var sound = Sound(duration: musicDuration)
    let counter = [72, 74, 76, 79, 76, 74, 72, 67]
    for bar in 0..<16 {
        let barStart = Double(bar) * barDuration
        addClap(to: &sound, at: barStart + beatDuration, seed: UInt64(5000 + bar), gain: 0.18)
        addClap(to: &sound, at: barStart + beatDuration * 3, seed: UInt64(6000 + bar), gain: 0.18)
        for eighth in 0..<8 {
            let time = barStart + Double(eighth) * beatDuration / 2
            if eighth % 2 == 1 {
                sound.tone(start: time, duration: beatDuration * 0.20, frequency: frequency(counter[(eighth + bar * 2) % counter.count] + 12), gain: 0.13, waveform: .triangle, attack: 0.02, releasePower: 3.2)
            }
        }
        if bar % 4 == 3 {
            for step in 0..<4 {
                // Keep the final hit inside the bar so the repeated stem has a clean boundary.
                addSnare(to: &sound, at: barStart + beatDuration * (3 + Double(step) / 5), seed: UInt64(7000 + bar * 10 + step), gain: 0.16 + Double(step) * 0.025)
            }
        }
    }
    sound.normalize()
    return sound
}

private func makeLaunch() -> Sound {
    var sound = Sound(duration: 0.38)
    sound.glide(start: 0, duration: 0.32, from: 210, to: 620, gain: 0.38, waveform: .triangle)
    sound.noise(start: 0, duration: 0.22, gain: 0.11, seed: 81, releasePower: 2.8)
    return sound
}

private func makeBlocked() -> Sound {
    var sound = Sound(duration: 0.32)
    sound.glide(start: 0, duration: 0.24, from: 210, to: 118, gain: 0.48, waveform: .softSquare)
    sound.tone(start: 0.02, duration: 0.10, frequency: 520, gain: 0.10, waveform: .triangle, releasePower: 4)
    return sound
}

private func makeMatch() -> Sound {
    var sound = Sound(duration: 0.62)
    for (index, note) in [72, 76, 79].enumerated() {
        sound.tone(start: Double(index) * 0.085, duration: 0.30, frequency: frequency(note), gain: 0.28, waveform: .triangle, releasePower: 2.8)
    }
    return sound
}

private func makeChain() -> Sound {
    var sound = Sound(duration: 0.78)
    for (index, note) in [76, 79, 84, 88, 91].enumerated() {
        sound.tone(start: Double(index) * 0.075, duration: 0.32, frequency: frequency(note), gain: 0.22, waveform: .triangle, releasePower: 2.8)
    }
    return sound
}

private func makeBomb() -> Sound {
    var sound = Sound(duration: 0.85)
    sound.glide(start: 0, duration: 0.20, from: 760, to: 180, gain: 0.24, waveform: .triangle)
    sound.add(start: 0.18, duration: 0.60, gain: 0.62) { time, progress in
        sin(twoPi * (70 - 30 * progress) * time)
    }
    sound.noise(start: 0.17, duration: 0.42, gain: 0.30, seed: 991, releasePower: 2.6)
    sound.normalize()
    return sound
}

private func makeLine() -> Sound {
    var sound = Sound(duration: 0.72)
    sound.glide(start: 0, duration: 0.56, from: 280, to: 1_520, gain: 0.28, waveform: .sine)
    sound.glide(start: 0.04, duration: 0.50, from: 190, to: 970, gain: 0.18, waveform: .triangle)
    sound.noise(start: 0.05, duration: 0.42, gain: 0.07, seed: 474, releasePower: 2.2)
    return sound
}

private func makeHop() -> Sound {
    var sound = Sound(duration: 0.42)
    sound.glide(start: 0, duration: 0.26, from: 170, to: 330, gain: 0.34, waveform: .softSquare)
    sound.tone(start: 0.12, duration: 0.20, frequency: 510, gain: 0.15, waveform: .triangle, releasePower: 3)
    return sound
}

private func makeRescue() -> Sound {
    var sound = Sound(duration: 1.1)
    sound.noise(start: 0, duration: 0.34, gain: 0.32, seed: 2_024, releasePower: 3)
    sound.glide(start: 0.18, duration: 0.70, from: 410, to: 820, gain: 0.24, waveform: .sine)
    sound.tone(start: 0.65, duration: 0.30, frequency: frequency(79), gain: 0.15, waveform: .triangle, releasePower: 2.6)
    return sound
}

private func makeDanceStinger() -> Sound {
    var sound = Sound(duration: 1.2)
    for (index, note) in [60, 64, 67, 72].enumerated() {
        let start = Double(index) * 0.10
        sound.tone(start: start, duration: 0.55, frequency: frequency(note), gain: 0.24, waveform: .softSquare, releasePower: 2.3)
    }
    addClap(to: &sound, at: 0.43, seed: 8_080, gain: 0.24)
    addClap(to: &sound, at: 0.70, seed: 8_081, gain: 0.20)
    return sound
}

private func makeWin() -> Sound {
    var sound = Sound(duration: 1.8)
    for (index, note) in [60, 64, 67, 72, 76, 79].enumerated() {
        sound.tone(start: Double(index) * 0.12, duration: 0.65, frequency: frequency(note), gain: 0.23, waveform: .triangle, releasePower: 2.4)
    }
    addChord(to: &sound, at: 0.82, notes: [60, 64, 67, 72], duration: 0.88, gain: 0.50, waveform: .softSquare)
    return sound
}

private func makeLose() -> Sound {
    var sound = Sound(duration: 1.25)
    for (index, note) in [67, 64, 62, 60].enumerated() {
        sound.tone(start: Double(index) * 0.17, duration: 0.42, frequency: frequency(note), gain: 0.20, waveform: .triangle, releasePower: 2.5)
    }
    sound.tone(start: 0.73, duration: 0.42, frequency: frequency(67), gain: 0.11, waveform: .sine, releasePower: 2.4)
    return sound
}

private func writeWAV(_ sound: Sound, to url: URL) throws {
    var sound = sound
    sound.normalize()
    let pcm = sound.samples.map { sample -> Int16 in
        let clipped = min(1, max(-1, sample))
        return Int16(clipped * Double(Int16.max))
    }
    let dataSize = UInt32(pcm.count * MemoryLayout<Int16>.size)
    var data = Data()

    func appendASCII(_ value: String) {
        data.append(value.data(using: .ascii)!)
    }
    func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: 2))
    }
    func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: 4))
    }

    appendASCII("RIFF")
    appendUInt32(36 + dataSize)
    appendASCII("WAVE")
    appendASCII("fmt ")
    appendUInt32(16)
    appendUInt16(1)
    appendUInt16(1)
    appendUInt32(UInt32(sampleRate))
    appendUInt32(UInt32(sampleRate * 2))
    appendUInt16(2)
    appendUInt16(16)
    appendASCII("data")
    appendUInt32(dataSize)
    for var sample in pcm.map(\.littleEndian) {
        data.append(Data(bytes: &sample, count: 2))
    }
    try data.write(to: url, options: .atomic)
}

private func generateAssets() throws {
    let scriptURL = URL(fileURLWithPath: #filePath)
    let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    let outputDirectory = projectRoot.appendingPathComponent("BunBun/Resources/Audio", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let base = makeBase()
    let melody = makeMelody()
    let pressure = makePressure()
    let dance = makeDance()
    let assets: [(String, Sound)] = [
        ("MusicBase.wav", base),
        ("MusicMelody.wav", melody),
        ("MusicPressure.wav", pressure),
        ("MusicDance.wav", dance),
        ("SFXLaunch.wav", makeLaunch()),
        ("SFXBlocked.wav", makeBlocked()),
        ("SFXMatch.wav", makeMatch()),
        ("SFXChain.wav", makeChain()),
        ("SFXBomb.wav", makeBomb()),
        ("SFXLine.wav", makeLine()),
        ("SFXHop.wav", makeHop()),
        ("SFXRescue.wav", makeRescue()),
        ("SFXDance.wav", makeDanceStinger()),
        ("SFXWin.wav", makeWin()),
        ("SFXLose.wav", makeLose())
    ]

    for (name, sound) in assets {
        let url = outputDirectory.appendingPathComponent(name)
        try writeWAV(sound, to: url)
        print("Wrote \(name)")
    }

    // A convenient full-mix reference for listening outside the game.
    var preview = base.mixed(with: melody, gain: 0.78)
    preview = preview.mixed(with: pressure, gain: 0.35)
    preview = preview.mixed(with: dance, gain: 0.70)
    try writeWAV(preview, to: outputDirectory.appendingPathComponent("BunBunThemePreview.wav"))
    print("Wrote BunBunThemePreview.wav")
}

try generateAssets()
