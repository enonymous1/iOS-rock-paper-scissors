import Foundation

/// Every message one player can send the other.
///
/// v1 sent two unrelated shapes over the same channel: a single raw
/// Bool byte for "I pressed Play" and a PNG for a throw, told apart
/// only by peeking at the first byte. One typed message replaces
/// both, so a malformed packet is a decoding error instead of a
/// crash or a misread throw.
enum PeerMessage: Codable, Equatable, Sendable {
    /// "I pressed Play." A round starts only once both sides have
    /// sent this, exactly like v1's handshake, but now typed.
    case play

    /// A throw, sent at SHOOT. The throw travels as a word, not an
    /// image, so both sides resolve the round from the same enum.
    case throw(Throw)

    /// "Play again." Resets the round on both sides but keeps the
    /// score; v1 had no rematch at all.
    case rematch

    private enum CodingKeys: String, CodingKey {
        case type
        case throw
    }

    private enum MessageType: String, Codable {
        case play
        case throw
        case rematch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(MessageType.self, forKey: .type) {
        case .play:
            self = .play
        case .throw:
            self = .throw(try container.decode(Throw.self, forKey: .throw))
        case .rematch:
            self = .rematch
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .play:
            try container.encode(MessageType.play, forKey: .type)
        case .throw(let value):
            try container.encode(MessageType.throw, forKey: .type)
            try container.encode(value, forKey: .throw)
        case .rematch:
            try container.encode(MessageType.rematch, forKey: .type)
        }
    }

    /// Encodes the message for `MCSession.send`. Throws instead of
    /// v1's `try?`, so a caller can surface the failure.
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a message received from a peer. Returns nil for data
    /// that is not a message at all, instead of v1's `data[0]`
    /// subscript, which crashed on an empty packet.
    static func decoded(from data: Data) -> PeerMessage? {
        try? JSONDecoder().decode(PeerMessage.self, from: data)
    }
}
