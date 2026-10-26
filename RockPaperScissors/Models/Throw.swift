import Foundation

/// One throw in Rock Paper Scissors.
///
/// v1 sent the throw as a PNG over MultipeerConnectivity, so the
/// meaning of a message depended on which image asset happened to be
/// attached. v2 sends this enum instead: a few bytes, unambiguous,
/// and independent of the artwork.
enum Throw: String, CaseIterable, Codable, Equatable, Sendable {
    case rock
    case paper
    case scissors

    /// The asset-catalog image for this throw. The artwork is the
    /// original 256x256 v1 PNG, kept so the game still looks like
    /// itself; only the wire format changed.
    var imageName: String { rawValue }

    /// True when this throw beats the other throw: rock beats
    /// scissors, scissors beats paper, paper beats rock.
    func beats(_ other: Throw) -> Bool {
        switch (self, other) {
        case (.rock, .scissors), (.scissors, .paper), (.paper, .rock):
            return true
        default:
            return false
        }
    }
}
