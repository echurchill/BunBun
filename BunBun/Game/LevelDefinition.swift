import Foundation

enum LevelID: String, CaseIterable, Codable, Sendable {
    case bunnyLab
    case carrotWorks
    case moonlightMeadow
    case fireflyFalls
    case danceRehearsal
    case birthdayBash
}

enum LevelTheme: String, Codable, Sendable {
    case lab
    case meadow
    case rehearsal

    var backgroundAssetName: String {
        switch self {
        case .lab: "BackgroundCarrotWorkshop"
        case .meadow: "BackgroundMoonlitGarden"
        case .rehearsal: "BackgroundBirthdayPavilion"
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
    let rules: GameRules
    let startingLayout: [Cell: PrototypeShot]
    let shotSequence: [PrototypeShot]
    let arrivalPalette: [BunnyColor]
    let arrivalSeed: Int
    let arrivalGapModulo: Int
    let arrivalColorStride: Int
    let arrivalTurnStride: Int
    let tutorialPrompts: [String]

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
            let colorIndex = abs(
                column * arrivalColorStride
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
        moonlightMeadow,
        fireflyFalls,
        danceRehearsal,
        birthdayBash
    ]

    static let bunnyLab = LevelDefinition(
        id: .bunnyLab,
        displayName: "Bunny Lab",
        subtitle: "Learn the three-sided board",
        theme: .lab,
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
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 90,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 3,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 8,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 100,
            danceChargePerMatchedBunny: 12,
            danceChargePerSpecialEffectBunny: 5,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 110
        ),
        startingLayout: layout([
            7: [1: .green, 2: .purple, 3: .orange, 4: .blue, 5: .pink,
                6: .green, 7: .blue, 8: .purple, 9: .orange, 10: .pink],
            6: [1: .orange, 2: .blue, 3: .pink, 4: .green, 5: .purple,
                6: .orange, 7: .pink, 8: .green, 9: .blue, 10: .purple],
            5: [1: .pink, 3: .green, 4: .purple, 6: .blue,
                7: .orange, 9: .pink, 10: .green],
            4: [2: .purple, 4: .orange, 5: .blue, 7: .pink, 8: .green, 10: .orange]
        ]),
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
        startingLayout: layout([
            7: [1: .blue, 2: .green, 3: .orange, 4: .pink, 5: .purple,
                6: .blue, 7: .green, 8: .orange, 9: .pink, 10: .purple],
            6: [1: .purple, 2: .blue, 3: .green, 4: .orange, 5: .pink,
                6: .purple, 7: .blue, 8: .green, 9: .orange, 10: .pink],
            5: [2: .orange, 3: .pink, 4: .purple, 5: .blue, 6: .green,
                7: .orange, 8: .pink, 9: .purple, 10: .blue],
            4: [1: .green, 2: .purple, 3: .blue, 4: .green, 5: .orange,
                6: .pink, 7: .purple, 8: .blue, 9: .green, 10: .orange]
        ]),
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
        rules: GameRules(
            launchesPerAdvance: 2,
            progressTarget: 80,
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
            pointsPerRemovedBunny: 125
        ),
        startingLayout: layout([
            7: [1: .pink, 2: .blue, 3: .purple, 4: .orange, 5: .green,
                6: .pink, 7: .orange, 8: .blue, 9: .green, 10: .purple],
            6: [1: .blue, 2: .green, 3: .orange, 4: .pink, 5: .purple,
                6: .blue, 7: .purple, 8: .green, 9: .pink, 10: .orange],
            5: [1: .purple, 2: .orange, 4: .green, 5: .blue,
                7: .pink, 8: .purple, 10: .green],
            4: [2: .pink, 3: .blue, 5: .orange, 6: .purple,
                8: .green, 9: .blue]
        ]),
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
        rules: GameRules(
            launchesPerAdvance: 3,
            progressTarget: 95,
            progressPerMatchedBunny: 3,
            progressPerSpecialEffectBunny: 1,
            progressDecayPerAdvance: 4,
            progressLostPerFallenBunny: 3,
            dangerLimit: 100,
            dangerPerFallenBunny: 9,
            dangerReliefPerClearedBunny: 2,
            danceTarget: 95,
            danceChargePerMatchedBunny: 13,
            danceChargePerSpecialEffectBunny: 6,
            dancePartyLength: 4,
            pointsPerRemovedBunny: 115
        ),
        startingLayout: layout([
            7: [1: .purple, 2: .pink, 3: .blue, 4: .green, 5: .orange,
                6: .purple, 7: .pink, 8: .blue, 9: .green, 10: .orange],
            6: [1: .orange, 2: .purple, 3: .pink, 4: .blue, 5: .green,
                6: .orange, 7: .purple, 8: .pink, 9: .blue, 10: .green],
            5: [1: .blue, 2: .green, 4: .purple, 5: .pink,
                7: .orange, 8: .blue, 10: .purple],
            4: [2: .pink, 3: .orange, 5: .blue, 6: .purple,
                8: .green, 9: .pink]
        ]),
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
        rules: GameRules(
            launchesPerAdvance: 2,
            progressTarget: 75,
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
            pointsPerRemovedBunny: 140
        ),
        startingLayout: layout([
            7: [1: .pink, 2: .purple, 3: .blue, 4: .orange, 5: .green,
                6: .pink, 7: .purple, 8: .blue, 9: .orange, 10: .green],
            6: [1: .green, 2: .pink, 3: .purple, 4: .blue, 5: .orange,
                6: .green, 7: .pink, 8: .purple, 9: .blue, 10: .orange],
            5: [1: .blue, 2: .orange, 3: .green, 5: .purple,
                6: .pink, 7: .blue, 9: .orange, 10: .green],
            4: [2: .purple, 3: .pink, 4: .blue, 6: .orange,
                7: .green, 8: .purple, 10: .pink]
        ]),
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
}
