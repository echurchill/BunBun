import Foundation

enum LevelID: String, CaseIterable, Codable, Sendable {
    case bunnyLab
    case carrotWorks
    case sunsetShuffle
    case meadowWarmup
    case riversideRomp
    case campfireCadence
    case moonlightMeadow
    case fireflyFalls
    case midnightEncore
    case danceRehearsal
    case snowflakeShuffle
    case birthdayBash
}

enum LevelTheme: String, Codable, Sendable {
    case lab
    case meadow
    case rehearsal
}

enum LevelEnvironment: String, CaseIterable, Codable, Sendable {
    case desertCamp
    case forestCampDay
    case forestCampNight
    case snowyWoodland

    var backgroundAssetName: String {
        switch self {
        case .desertCamp: "BackgroundDesertCamp"
        case .forestCampDay: "BackgroundForestCamp"
        case .forestCampNight: "BackgroundForestCampNight"
        case .snowyWoodland: "BackgroundSnowyWoodland"
        }
    }

    var displayName: String {
        switch self {
        case .desertCamp: "SUNSET CAMP"
        case .forestCampDay: "SPRINGTIME CAMP"
        case .forestCampNight: "MOONLIT CAMP"
        case .snowyWoodland: "WINTER CAMP"
        }
    }
}

struct GameRules: Equatable, Codable, Sendable {
    let launchesPerAdvance: Int
    let progressTarget: Int
    let progressPerMatchedBunny: Int
    let progressPerSpecialEffectBunny: Int
    let progressDecayPerAdvance: Int
    let progressLostPerFallenBunny: Int
    let dangerLimit: Int
    let dangerPerFallenBunny: Int
    let dangerReliefPerClearedBunny: Int
    let danceTarget: Int
    let danceChargePerMatchedBunny: Int
    let danceChargePerSpecialEffectBunny: Int
    let dancePartyLength: Int
    let pointsPerRemovedBunny: Int

    static let bunnyLab = GameRules(
        launchesPerAdvance: 3,
        progressTarget: 100,
        progressPerMatchedBunny: 3,
        progressPerSpecialEffectBunny: 1,
        progressDecayPerAdvance: 2,
        progressLostPerFallenBunny: 2,
        dangerLimit: 100,
        dangerPerFallenBunny: 6,
        dangerReliefPerClearedBunny: 3,
        danceTarget: 100,
        danceChargePerMatchedBunny: 14,
        danceChargePerSpecialEffectBunny: 4,
        dancePartyLength: 4,
        pointsPerRemovedBunny: 100
    )
}

struct LevelDefinition: Equatable, Sendable {
    let id: LevelID
    let displayName: String
    let subtitle: String
    let theme: LevelTheme
    let environment: LevelEnvironment
    let rules: GameRules
    let startingLayout: [Cell: PrototypeShot]
    let shotSequence: [PrototypeShot]
    let arrivalPalette: [BunnyColor]
    let arrivalSeed: Int
    let arrivalGapModulo: Int
    let arrivalColorStride: Int
    let arrivalTurnStride: Int
    let tutorialPrompts: [String]

    var backgroundAssetName: String {
        environment.backgroundAssetName
    }

    func startingBoard() -> Board {
        var board = Board()
        for (cell, descriptor) in startingLayout {
            _ = board.place(descriptor.makeBunny(), at: cell)
        }
        return board
    }

    func shot(at index: Int) -> PrototypeShot {
        precondition(!shotSequence.isEmpty)
        return shotSequence[index % shotSequence.count]
    }

    /// Returns descriptors rather than live bunnies so tests and replays can
    /// verify the seeded pattern without UUIDs making identical rows unequal.
    func arrivalPattern(forTurn turn: Int) -> [Int: PrototypeShot] {
        precondition(!arrivalPalette.isEmpty)
        precondition(arrivalGapModulo > 1)

        return Dictionary(uniqueKeysWithValues: Board.marchingColumns.compactMap { column in
            let gapValue = column + turn + arrivalSeed
            guard gapValue % arrivalGapModulo != 0 else { return nil }

            // The original game favors tempting almost-matches instead of a
            // uniformly alternating checkerboard. Shift the two-wide bands
            // each turn so arrivals usually contain several adjacent pairs,
            // while moving gaps keep those pairs from becoming automatic
            // three-bunny matches.
            let pairPhase = abs(turn + arrivalSeed) % 2
            let pairBand = (column + pairPhase) / 2
            let colorIndex = abs(
                pairBand * arrivalColorStride
                    + turn * arrivalTurnStride
                    + arrivalSeed
            ) % arrivalPalette.count
            return (column, PrototypeShot(color: arrivalPalette[colorIndex]))
        })
    }

    func advanceRow(forTurn turn: Int) -> [Int: Bunny] {
        arrivalPattern(forTurn: turn).mapValues { $0.makeBunny() }
    }

    func prompt(at shotIndex: Int) -> String {
        if tutorialPrompts.indices.contains(shotIndex) {
            return tutorialPrompts[shotIndex]
        }
        return "Tap a side box or touch below a column"
    }
}

enum LevelCatalog {
    static let levels: [LevelDefinition] = [
        bunnyLab,
        carrotWorks,
        sunsetShuffle,
        meadowWarmup,
        riversideRomp,
        campfireCadence,
        moonlightMeadow,
        fireflyFalls,
        midnightEncore,
        danceRehearsal,
        snowflakeShuffle,
        birthdayBash
    ]

    static let bunnyLab = LevelDefinition(
        id: .bunnyLab,
        displayName: "Bunny Lab",
        subtitle: "Learn the three-sided board",
        theme: .lab,
        environment: .desertCamp,
        rules: .bunnyLab,
        startingLayout: layout([
            7: [1: .orange, 2: .pink, 3: .green, 4: .purple, 5: .blue,
                6: .pink, 7: .green, 8: .orange, 9: .purple, 10: .purple],
            6: [1: .purple, 2: .orange, 3: .pink, 4: .blue, 5: .purple,
                6: .orange, 7: .pink, 8: .blue, 9: .green, 10: .green],
            5: [2: .blue, 3: .blue, 4: .orange, 5: .pink, 6: .purple,
                7: .green, 8: .orange, 9: .pink, 10: .blue],
            4: [1: .red, 2: .red, 3: .orange, 4: .purple, 5: .green,
                6: .orange, 7: .blue, 8: .purple, 9: .blue, 10: .orange]
        ]),
        shotSequence: [
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink)
        ],
        arrivalPalette: [.blue, .green, .orange, .pink, .purple],
        arrivalSeed: 0,
        arrivalGapModulo: 5,
        arrivalColorStride: 2,
        arrivalTurnStride: 1,
        tutorialPrompts: [
            "Tap the LEFT purple box beside the blue pair",
            "Tap the RIGHT purple box beside the green pair",
            "BOMB: tap LEFT beside the red pair",
            "LINE: tap RIGHT beside the purple pair"
        ]
    )

    static let moonlightMeadow = LevelDefinition(
        id: .moonlightMeadow,
        displayName: "Moonlight Meadow",
        subtitle: "Plan around denser arrivals",
        theme: .meadow,
        environment: .forestCampNight,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 95,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 8,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 95,
            danceChargePerMatchedBunny: 15,
            danceChargePerSpecialEffectBunny: 5,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 130
        ),
        startingLayout: nearMatchLayout(colorShift: 1, mirrored: true),
        shotSequence: [
            PrototypeShot(color: .green),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple),
            PrototypeShot(color: .green),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.green, .orange, .pink, .purple, .blue],
        arrivalSeed: 2,
        arrivalGapModulo: 7,
        arrivalColorStride: 3,
        arrivalTurnStride: 2,
        tutorialPrompts: []
    )

    static let carrotWorks = LevelDefinition(
        id: .carrotWorks,
        displayName: "Carrot Works",
        subtitle: "Keep the workshop humming",
        theme: .lab,
        environment: .desertCamp,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 105,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 2,
            dangerLimit: 100,
            dangerPerFallenBunny: 7,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 100,
            danceChargePerMatchedBunny: 13,
            danceChargePerSpecialEffectBunny: 5,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 105
        ),
        startingLayout: nearMatchLayout(colorShift: 2),
        shotSequence: [
            PrototypeShot(color: .orange),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .green),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.orange, .green, .blue, .pink, .purple],
        arrivalSeed: 1,
        arrivalGapModulo: 6,
        arrivalColorStride: 2,
        arrivalTurnStride: 3,
        tutorialPrompts: []
    )

    static let danceRehearsal = LevelDefinition(
        id: .danceRehearsal,
        displayName: "Dance Rehearsal",
        subtitle: "Build parties while pressure rises",
        theme: .rehearsal,
        environment: .snowyWoodland,
        rules: GameRules(
            launchesPerAdvance: 2,
            progressTarget: 85,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 2,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 8,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 80,
            danceChargePerMatchedBunny: 22,
            danceChargePerSpecialEffectBunny: 10,
            dancePartyLength: 5,
            pointsPerRemovedBunny: 140
        ),
        startingLayout: nearMatchLayout(colorShift: 3, flipped: true),
        shotSequence: [
            PrototypeShot(color: .pink),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .blue)
        ],
        arrivalPalette: [.pink, .purple, .blue, .green, .orange],
        arrivalSeed: 4,
        arrivalGapModulo: 8,
        arrivalColorStride: 2,
        arrivalTurnStride: 3,
        tutorialPrompts: []
    )

    static let fireflyFalls = LevelDefinition(
        id: .fireflyFalls,
        displayName: "Firefly Falls",
        subtitle: "Find chains beneath the moon",
        theme: .meadow,
        environment: .forestCampNight,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 100,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 4,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 9,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 90,
            danceChargePerMatchedBunny: 16,
            danceChargePerSpecialEffectBunny: 6,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 135
        ),
        startingLayout: nearMatchLayout(colorShift: 4, mirrored: true, flipped: true),
        shotSequence: [
            PrototypeShot(color: .purple),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.purple, .blue, .green, .pink, .orange],
        arrivalSeed: 3,
        arrivalGapModulo: 7,
        arrivalColorStride: 2,
        arrivalTurnStride: 3,
        tutorialPrompts: []
    )

    static let birthdayBash = LevelDefinition(
        id: .birthdayBash,
        displayName: "Birthday Bash",
        subtitle: "Fill the floor for Beth's finale",
        theme: .rehearsal,
        environment: .snowyWoodland,
        rules: GameRules(
            launchesPerAdvance: 2,
            progressTarget: 95,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 9,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 70,
            danceChargePerMatchedBunny: 24,
            danceChargePerSpecialEffectBunny: 12,
            dancePartyLength: 5,
            pointsPerRemovedBunny: 150
        ),
        startingLayout: nearMatchLayout(colorShift: 0, mirrored: true),
        shotSequence: [
            PrototypeShot(color: .pink),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.pink, .purple, .blue, .orange, .green],
        arrivalSeed: 5,
        arrivalGapModulo: 9,
        arrivalColorStride: 3,
        arrivalTurnStride: 4,
        tutorialPrompts: []
    )

    static let sunsetShuffle = LevelDefinition(
        id: .sunsetShuffle,
        displayName: "Sunset Shuffle",
        subtitle: "Finish camp with longer combinations",
        theme: .lab,
        environment: .desertCamp,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 110,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 2,
            dangerLimit: 100,
            dangerPerFallenBunny: 7,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 95,
            danceChargePerMatchedBunny: 14,
            danceChargePerSpecialEffectBunny: 6,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 110
        ),
        startingLayout: nearMatchLayout(colorShift: 4, mirrored: true),
        shotSequence: [
            PrototypeShot(color: .green),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .green),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink)
        ],
        arrivalPalette: [.green, .orange, .blue, .pink, .purple],
        arrivalSeed: 6,
        arrivalGapModulo: 6,
        arrivalColorStride: 3,
        arrivalTurnStride: 2,
        tutorialPrompts: []
    )

    static let meadowWarmup = LevelDefinition(
        id: .meadowWarmup,
        displayName: "Meadow Warmup",
        subtitle: "Meet the springtime crowd",
        theme: .meadow,
        environment: .forestCampDay,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 95,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 2,
            progressLostPerFallenBunny: 2,
            dangerLimit: 100,
            dangerPerFallenBunny: 7,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 100,
            danceChargePerMatchedBunny: 14,
            danceChargePerSpecialEffectBunny: 5,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 115
        ),
        startingLayout: nearMatchLayout(colorShift: 1, flipped: true),
        shotSequence: [
            PrototypeShot(color: .pink),
            PrototypeShot(color: .green),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .green),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.pink, .green, .blue, .orange, .purple],
        arrivalSeed: 7,
        arrivalGapModulo: 6,
        arrivalColorStride: 2,
        arrivalTurnStride: 1,
        tutorialPrompts: []
    )

    static let riversideRomp = LevelDefinition(
        id: .riversideRomp,
        displayName: "Riverside Romp",
        subtitle: "Turn pairs into tumbling chains",
        theme: .meadow,
        environment: .forestCampDay,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 100,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 8,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 95,
            danceChargePerMatchedBunny: 15,
            danceChargePerSpecialEffectBunny: 6,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 120
        ),
        startingLayout: nearMatchLayout(colorShift: 2, mirrored: true, flipped: true),
        shotSequence: [
            PrototypeShot(color: .blue),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .green),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.blue, .orange, .pink, .green, .purple],
        arrivalSeed: 8,
        arrivalGapModulo: 7,
        arrivalColorStride: 3,
        arrivalTurnStride: 2,
        tutorialPrompts: []
    )

    static let campfireCadence = LevelDefinition(
        id: .campfireCadence,
        displayName: "Campfire Cadence",
        subtitle: "Keep the daytime finale moving",
        theme: .meadow,
        environment: .forestCampDay,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 105,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 4,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 8,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 90,
            danceChargePerMatchedBunny: 16,
            danceChargePerSpecialEffectBunny: 7,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 125
        ),
        startingLayout: nearMatchLayout(colorShift: 3, mirrored: true),
        shotSequence: [
            PrototypeShot(color: .orange),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .green),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .green)
        ],
        arrivalPalette: [.orange, .pink, .green, .blue, .purple],
        arrivalSeed: 9,
        arrivalGapModulo: 7,
        arrivalColorStride: 2,
        arrivalTurnStride: 3,
        tutorialPrompts: []
    )

    static let midnightEncore = LevelDefinition(
        id: .midnightEncore,
        displayName: "Midnight Encore",
        subtitle: "Hold the moonlit stage together",
        theme: .meadow,
        environment: .forestCampNight,
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 105,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 5,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 9,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 85,
            danceChargePerMatchedBunny: 17,
            danceChargePerSpecialEffectBunny: 8,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 135
        ),
        startingLayout: nearMatchLayout(colorShift: 0, flipped: true),
        shotSequence: [
            PrototypeShot(color: .purple),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .green),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .pink)
        ],
        arrivalPalette: [.purple, .blue, .pink, .green, .orange],
        arrivalSeed: 10,
        arrivalGapModulo: 8,
        arrivalColorStride: 3,
        arrivalTurnStride: 4,
        tutorialPrompts: []
    )

    static let snowflakeShuffle = LevelDefinition(
        id: .snowflakeShuffle,
        displayName: "Snowflake Shuffle",
        subtitle: "Dance between faster advances",
        theme: .rehearsal,
        environment: .snowyWoodland,
        rules: GameRules(
            launchesPerAdvance: 2,
            progressTarget: 90,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 9,
            dangerReliefPerClearedBunny: 3,
            danceTarget: 75,
            danceChargePerMatchedBunny: 23,
            danceChargePerSpecialEffectBunny: 11,
            dancePartyLength: 5,
            pointsPerRemovedBunny: 145
        ),
        startingLayout: nearMatchLayout(colorShift: 4),
        shotSequence: [
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .pink),
            PrototypeShot(color: .green),
            PrototypeShot(color: .purple, kind: .lineClear),
            PrototypeShot(color: .orange),
            PrototypeShot(color: .red, kind: .redBomb),
            PrototypeShot(color: .blue),
            PrototypeShot(color: .purple, kind: .lineClear)
        ],
        arrivalPalette: [.blue, .purple, .pink, .green, .orange],
        arrivalSeed: 11,
        arrivalGapModulo: 8,
        arrivalColorStride: 2,
        arrivalTurnStride: 4,
        tutorialPrompts: []
    )

    static func definition(for id: LevelID) -> LevelDefinition {
        levels.first { $0.id == id } ?? bunnyLab
    }

    static func nextLevel(after id: LevelID) -> LevelDefinition? {
        guard let index = levels.firstIndex(where: { $0.id == id }),
              levels.indices.contains(index + 1) else { return nil }
        return levels[index + 1]
    }

    private static func layout(_ rows: [Int: [Int: BunnyColor]]) -> [Cell: PrototypeShot] {
        var result: [Cell: PrototypeShot] = [:]
        for (row, columns) in rows {
            for (column, color) in columns {
                result[Cell(column: column, row: row)] = PrototypeShot(color: color)
            }
        }
        return result
    }

    /// Curated match-free formation with several adjacent pairs and open
    /// approach lanes. Color shifts and reflections provide repeatable stage
    /// variants without losing the carefully checked near-match topology.
    private static func nearMatchLayout(
        colorShift: Int,
        mirrored: Bool = false,
        flipped: Bool = false
    ) -> [Cell: PrototypeShot] {
        let base = layout([
            7: [1: .blue, 2: .blue, 3: .green, 4: .orange, 5: .orange,
                6: .pink, 7: .purple, 8: .purple, 9: .green, 10: .pink],
            6: [1: .orange, 2: .pink, 3: .pink, 4: .purple, 5: .green,
                6: .green, 7: .blue, 8: .orange, 9: .orange, 10: .purple],
            5: [1: .purple, 2: .purple, 4: .blue, 5: .blue,
                7: .pink, 8: .pink, 10: .green],
            4: [2: .orange, 3: .orange, 6: .purple, 7: .purple,
                9: .blue, 10: .blue]
        ])
        let palette: [BunnyColor] = [.blue, .green, .orange, .pink, .purple]

        return Dictionary(uniqueKeysWithValues: base.map { cell, shot in
            let column = mirrored ? 11 - cell.column : cell.column
            let row = flipped ? 11 - cell.row : cell.row
            let color: BunnyColor
            if let index = palette.firstIndex(of: shot.color) {
                color = palette[(index + colorShift) % palette.count]
            } else {
                color = shot.color
            }
            return (Cell(column: column, row: row), PrototypeShot(color: color, kind: shot.kind))
        })
    }
}
