import SwiftUI

enum Theme {
    static let coral = Color(red: 0.93, green: 0.36, blue: 0.24)
    static let magenta = Color(red: 0.66, green: 0.20, blue: 0.47)
    static let sun = Color(red: 1.00, green: 0.78, blue: 0.35)

    static let gradient = LinearGradient(
        colors: [coral, magenta],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Word {
    /// Deep link that opens the app on this word and plays it.
    var deepLink: URL { URL(string: "palabra://word/\(id)?play=1")! }
}
