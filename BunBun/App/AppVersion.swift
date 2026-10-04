import Foundation

/// Single source of truth for the prototype version shown in the HUD and the
/// level picker. Production builds read Xcode's `MARKETING_VERSION` from the
/// app bundle, so bumping the version never leaves a stale string on screen.
enum AppVersion {
    static var marketingVersion: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
            return version
        }
        // Previews and unit tests run without the app bundle; keep this in
        // sync with MARKETING_VERSION in the Xcode project.
        return "0.5"
    }

    static var prototypeTag: String {
        "PROTOTYPE \(marketingVersion)"
    }
}
