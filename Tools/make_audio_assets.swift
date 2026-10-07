import Foundation

private let sampleRate = 22_050
private let tempo = 116.0
private let beatDuration = 60.0 / tempo
private let barDuration = beatDuration * 4
private let musicDuration = barDuration * 32
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

private struct NoteStep {
    let step: Int
    let note: Int
    let length: Int
    let accent: Double
}

/// A bright, rounded pluck made from inexpensive harmonic layers. It carries
/// the main hook more clearly than the old single triangle oscillator while
/// remaining deliberately synthetic and fully reproducible.
private func addPluck(
    to sound: inout Sound,
    at time: Double,
    note: Int,
    duration: Double,
    gain: Double
) {
    let fundamental = frequency(note)
    sound.tone(
        start: time,
        duration: duration,
        frequency: fundamental,
        gain: gain,
        waveform: .triangle,
        attack: 0.008,
        releasePower: 3.1
    )
    sound.tone(
        start: time,
        duration: duration * 0.72,
        frequency: fundamental * 2,
        gain: gain * 0.23,
        waveform: .sine,
        attack: 0.006,
        releasePower: 3.8
    )
    sound.tone(
        start: time,
        duration: duration * 0.48,
        frequency: fundamental * 3,
        gain: gain * 0.07,
        waveform: .sine,
        attack: 0.004,
        releasePower: 4.6
    )
}

private func makeBase() -> Sound {
    var sound = Sound(duration: musicDuration)
    // Eight-bar C-major progression: familiar first half, warmer answer in
    // the second. Four repetitions make a roughly 66-second fatigue-friendly
    // loop rather than the previous 33-second cycle.
    let roots = [48, 45, 41, 43, 48, 40, 41, 43] // C, A, F, G, C, E, F, G
    let chords = [
        [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62],
        [60, 64, 67], [52, 55, 59], [53, 57, 60], [55, 59, 62]
    ]
    let bassPatterns: [[Int?]] = [
        [0, nil, 12, 7, 0, nil, 7, 12],
        [0, 7, 12, nil, 0, 12, 7, nil],
        [0, nil, 7, 12, 0, 7, 10, 7],
        [0, 7, nil, 12, 0, 10, 7, 12]
    ]

    for bar in 0..<32 {
        let barStart = Double(bar) * barDuration
        let harmony = bar % roots.count
        let phrase = bar / 8
        for beat in 0..<4 {
            let time = barStart + Double(beat) * beatDuration
            if beat == 0 || beat == 2 {
                addKick(to: &sound, at: time, gain: beat == 0 ? 0.70 : 0.56)
            }
            if beat == 1 || beat == 3 { addSnare(to: &sound, at: time, seed: UInt64(bar * 10 + beat)) }
            if harmony == 7 && beat == 3 {
                addKick(to: &sound, at: time + beatDuration * 0.72, gain: 0.38)
            }
        }

        let bassPattern = bassPatterns[bar % bassPatterns.count]
        for eighth in 0..<8 {
            let time = barStart + Double(eighth) * beatDuration / 2
            addHat(
                to: &sound,
                at: time,
                seed: UInt64(1_000 + bar * 20 + eighth),
                gain: eighth.isMultiple(of: 2) ? 0.062 : 0.105
            )
            guard let interval = bassPattern[eighth] else { continue }
            let bassNote = roots[harmony] + interval
            sound.tone(
                start: time,
                duration: beatDuration * (eighth == 7 ? 0.28 : 0.40),
                frequency: frequency(bassNote),
                gain: phrase == 2 ? 0.23 : 0.27,
                waveform: .softSquare,
                attack: 0.015,
                releasePower: 1.65
            )
        }

        addChord(
            to: &sound,
            at: barStart + beatDuration * 0.48,
            notes: chords[harmony],
            duration: beatDuration * 0.48,
            gain: 0.25
        )
        addChord(
            to: &sound,
            at: barStart + beatDuration * 2.48,
            notes: chords[harmony],
            duration: beatDuration * 0.58,
            gain: 0.22
        )
        if phrase == 1 || phrase == 3 {
            addChord(
                to: &sound,
                at: barStart + beatDuration * 3.48,
                notes: chords[harmony],
                duration: beatDuration * 0.30,
                gain: 0.12
            )
        }
    }
    sound.normalize()
    return sound
}

private func makeMelody() -> Sound {
    var sound = Sound(duration: musicDuration)
    // Original syncopated four-bar call-and-response hook. The repeated
    // short-long "bun-bun" pickup gives the tune a stronger verbal shape,
    // while the bridge leaves breathing room during a long puzzle session.
    let hook: [[NoteStep]] = [
        [
            NoteStep(step: 0, note: 76, length: 2, accent: 1.0),
            NoteStep(step: 3, note: 79, length: 1, accent: 0.82),
            NoteStep(step: 5, note: 81, length: 2, accent: 0.96),
            NoteStep(step: 8, note: 79, length: 2, accent: 0.90),
            NoteStep(step: 11, note: 76, length: 1, accent: 0.76),
            NoteStep(step: 13, note: 74, length: 2, accent: 0.84)
        ],
        [
            NoteStep(step: 0, note: 79, length: 2, accent: 0.96),
            NoteStep(step: 3, note: 84, length: 2, accent: 1.0),
            NoteStep(step: 6, note: 83, length: 1, accent: 0.72),
            NoteStep(step: 8, note: 81, length: 2, accent: 0.90),
            NoteStep(step: 11, note: 79, length: 1, accent: 0.76),
            NoteStep(step: 13, note: 76, length: 2, accent: 0.88)
        ],
        [
            NoteStep(step: 0, note: 77, length: 2, accent: 0.92),
            NoteStep(step: 3, note: 81, length: 1, accent: 0.78),
            NoteStep(step: 5, note: 84, length: 2, accent: 1.0),
            NoteStep(step: 8, note: 81, length: 2, accent: 0.88),
            NoteStep(step: 11, note: 79, length: 1, accent: 0.75),
            NoteStep(step: 13, note: 76, length: 2, accent: 0.82)
        ],
        [
            NoteStep(step: 0, note: 74, length: 2, accent: 0.85),
            NoteStep(step: 3, note: 79, length: 1, accent: 0.78),
            NoteStep(step: 5, note: 83, length: 2, accent: 0.95),
            NoteStep(step: 8, note: 86, length: 1, accent: 0.86),
            NoteStep(step: 10, note: 84, length: 2, accent: 1.0),
            NoteStep(step: 13, note: 79, length: 1, accent: 0.72),
            NoteStep(step: 15, note: 76, length: 1, accent: 0.88)
        ]
    ]
    let bridge: [[NoteStep]] = [
        [
            NoteStep(step: 0, note: 72, length: 3, accent: 0.70),
            NoteStep(step: 6, note: 76, length: 2, accent: 0.68),
            NoteStep(step: 11, note: 79, length: 3, accent: 0.76)
        ],
        [
            NoteStep(step: 2, note: 71, length: 2, accent: 0.66),
            NoteStep(step: 7, note: 74, length: 2, accent: 0.68),
            NoteStep(step: 12, note: 79, length: 2, accent: 0.74)
        ],
        [
            NoteStep(step: 0, note: 69, length: 3, accent: 0.64),
            NoteStep(step: 6, note: 72, length: 2, accent: 0.68),
            NoteStep(step: 11, note: 76, length: 3, accent: 0.74)
        ],
        [
            NoteStep(step: 2, note: 74, length: 2, accent: 0.68),
            NoteStep(step: 7, note: 79, length: 2, accent: 0.74),
            NoteStep(step: 12, note: 83, length: 3, accent: 0.82)
        ]
    ]

    for bar in 0..<32 {
        let barStart = Double(bar) * barDuration
        let isBridge = (8..<12).contains(bar) || (24..<28).contains(bar)
        let phrase = isBridge ? bridge[bar % 4] : hook[bar % 4]
        let sectionGain = isBridge ? 0.17 : 0.23
        for event in phrase {
            let time = barStart + Double(event.step) * beatDuration / 4
            let duration = Double(event.length) * beatDuration / 4 * 0.90
            addPluck(
                to: &sound,
                at: time,
                note: event.note,
                duration: duration,
                gain: sectionGain * event.accent
            )
            // A quiet dotted echo helps the hook sing without turning the
            // normal puzzle mix into a wall of notes.
            addPluck(
                to: &sound,
                at: time + beatDuration * 0.36,
                note: event.note,
                duration: duration * 0.58,
                gain: sectionGain * event.accent * 0.14
            )
        }
    }
    sound.normalize()
    return sound
}

private func makePressure() -> Sound {
    var sound = Sound(duration: musicDuration)
    let pulseNotes = [72, 69, 65, 67, 72, 64, 65, 67]
    for bar in 0..<32 {
        let barStart = Double(bar) * barDuration
        for sixteenth in 0..<16 {
            let time = barStart + Double(sixteenth) * beatDuration / 4
            if sixteenth % 2 == 1 {
                addHat(to: &sound, at: time, seed: UInt64(3000 + bar * 20 + sixteenth), gain: sixteenth % 4 == 3 ? 0.13 : 0.075)
            }
        }
        for beat in 0..<4 {
            let time = barStart + Double(beat) * beatDuration
            sound.tone(
                start: time,
                duration: 0.10,
                frequency: frequency(pulseNotes[bar % pulseNotes.count] + (beat == 3 ? 7 : 0)),
                gain: 0.105,
                waveform: .square,
                attack: 0.01,
                releasePower: 4.5
            )
        }
    }
    sound.normalize()
    return sound
}

private func makeDance() -> Sound {
    var sound = Sound(duration: musicDuration)
    let roots = [48, 45, 41, 43, 48, 40, 41, 43]
    let chords = [
        [72, 76, 79], [69, 72, 76], [65, 69, 72], [67, 71, 74],
        [72, 76, 79], [64, 67, 71], [65, 69, 72], [67, 71, 74]
    ]
    let partyAnswers = [84, 79, 81, 76, 84, 83, 81, 79]
    for bar in 0..<32 {
        let barStart = Double(bar) * barDuration

        // A clear four-on-the-floor pulse makes the party audible immediately,
        // no matter which beat happens to be playing when the layer fades in.
        for beat in 0..<4 {
            let time = barStart + Double(beat) * beatDuration
            addKick(to: &sound, at: time, gain: beat == 0 ? 0.72 : 0.60)
            if beat == 1 || beat == 3 {
                addClap(to: &sound, at: time, seed: UInt64(5000 + bar * 10 + beat), gain: 0.27)
            }
        }

        let harmony = bar % roots.count
        let root = roots[harmony]
        for eighth in 0..<8 {
            let time = barStart + Double(eighth) * beatDuration / 2
            addHat(
                to: &sound,
                at: time,
                seed: UInt64(6500 + bar * 20 + eighth),
                gain: eighth.isMultiple(of: 2) ? 0.10 : 0.18
            )

            // Bouncy octave bass and a bright answer phrase distinguish this
            // from the calmer base groove without changing tempo or harmony.
            let bassNote = root + (eighth.isMultiple(of: 2) ? 12 : 0)
            sound.tone(start: time, duration: beatDuration * 0.31, frequency: frequency(bassNote), gain: 0.22, waveform: .softSquare, attack: 0.012, releasePower: 1.9)
            if eighth % 2 == 1 {
                addPluck(
                    to: &sound,
                    at: time,
                    note: partyAnswers[(eighth + bar) % partyAnswers.count],
                    duration: beatDuration * 0.28,
                    gain: 0.19
                )
            }
        }

        // Four off-beat disco stabs make the switch audible regardless of the
        // beat on which the Dance meter fills.
        for beat in 0..<4 {
            addChord(
                to: &sound,
                at: barStart + (Double(beat) + 0.48) * beatDuration,
                notes: chords[harmony],
                duration: beatDuration * 0.27,
                gain: beat.isMultiple(of: 2) ? 0.32 : 0.27
            )
        }

        if bar % 4 == 3 {
            for step in 0..<4 {
                // Keep the final hit inside the bar so the repeated stem has a clean boundary.
                addSnare(to: &sound, at: barStart + beatDuration * (3 + Double(step) / 5), seed: UInt64(7000 + bar * 10 + step), gain: 0.20 + Double(step) * 0.03)
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
    var sound = Sound(duration: 1.35)
    for (index, note) in [60, 64, 67, 72, 76].enumerated() {
        let start = Double(index) * 0.085
        sound.tone(start: start, duration: 0.62, frequency: frequency(note), gain: 0.28, waveform: .softSquare, releasePower: 2.3)
    }
    addKick(to: &sound, at: 0, gain: 0.70)
    addClap(to: &sound, at: 0.43, seed: 8_080, gain: 0.32)
    addClap(to: &sound, at: 0.70, seed: 8_081, gain: 0.27)
    sound.glide(start: 0.38, duration: 0.75, from: 520, to: 1_560, gain: 0.16, waveform: .triangle)
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
    // The listening preview stays outside Resources so the Audio folder
    // reference never embeds it in the app bundle.
    let previewDirectory = projectRoot.appendingPathComponent("Tools/AudioPreview", isDirectory: true)
    try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)

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

    // A convenient A/B reference for listening outside the game: sixteen bars
    // of the regular mix followed by sixteen bars of the dance-party mix.
    var preview = Sound(duration: musicDuration)
    let transitionSample = preview.samples.count / 2
    for index in preview.samples.indices {
        if index < transitionSample {
            preview.samples[index] = base.samples[index] * 0.50
                + melody.samples[index] * 0.34
                + pressure.samples[index] * 0.15
        } else {
            preview.samples[index] = base.samples[index] * 0.38
                + melody.samples[index] * 0.12
                + dance.samples[index] * 0.82
        }
    }
    let danceStinger = makeDanceStinger()
    for index in danceStinger.samples.indices where transitionSample + index < preview.samples.count {
        preview.samples[transitionSample + index] += danceStinger.samples[index] * 0.70
    }
    try writeWAV(preview, to: previewDirectory.appendingPathComponent("BunBunThemePreview.wav"))
    print("Wrote Tools/AudioPreview/BunBunThemePreview.wav")
}

try generateAssets()
