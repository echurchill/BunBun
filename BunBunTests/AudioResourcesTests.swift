import XCTest
@testable import BunBun

/// The Audio folder is embedded wholesale via a folder reference, so any
/// stray file silently ships in every install (as the listening preview
/// once did). This tripwire mirrors the shipped set in the test bundle and
/// fails if the folder gains or loses a file. When adding a legitimate cue
/// or stem, update `expectedFiles` alongside `AudioDirector`.
final class AudioResourcesTests: XCTestCase {
    private static let expectedFiles: Set<String> = [
        "MusicBase.wav",
        "MusicMelody.wav",
        "MusicPressure.wav",
        "MusicDance.wav",
        "SFXLaunch.wav",
        "SFXBlocked.wav",
        "SFXMatch.wav",
        "SFXChain.wav",
        "SFXBomb.wav",
        "SFXLine.wav",
        "SFXHop.wav",
        "SFXRescue.wav",
        "SFXDance.wav",
        "SFXWin.wav",
        "SFXLose.wav",
    ]

    func testAudioFolderContainsExactlyTheShippedCuesAndStems() throws {
        let audioDirectory = try XCTUnwrap(
            Bundle(for: Self.self).resourceURL?.appendingPathComponent("Audio"),
            "Test bundle is missing its Audio resources"
        )
        let contents = try FileManager.default.contentsOfDirectory(atPath: audioDirectory.path)
        XCTAssertEqual(Set(contents.filter { !$0.hasPrefix(".") }), Self.expectedFiles)
    }

    func testEveryCueResolvesToABundledFile() {
        for cue in AudioCue.allCases {
            XCTAssertNotNil(
                Bundle(for: Self.self).url(
                    forResource: cue.resourceName,
                    withExtension: "wav",
                    subdirectory: "Audio"
                ),
                "\(cue) should resolve to a bundled cue"
            )
        }
    }

    func testEveryMusicLayerResolvesToABundledFile() {
        for layer in AudioDirector.MusicLayer.allCases {
            XCTAssertNotNil(
                Bundle(for: Self.self).url(
                    forResource: layer.rawValue,
                    withExtension: "wav",
                    subdirectory: "Audio"
                ),
                "\(layer) should resolve to a bundled stem"
            )
        }
    }
}
