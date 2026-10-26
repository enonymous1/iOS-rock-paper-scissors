import Foundation
import Testing

@testable import RockPaperScissors

@Suite("Peer messages")
struct PeerMessageTests {
    @Test("Play, throw, and rematch all round-trip through JSON")
    func roundTrips() throws {
        let messages: [PeerMessage] = [.play, .throw(.scissors), .rematch]
        for message in messages {
            let data = try message.encoded()
            #expect(PeerMessage.decoded(from: data) == message)
        }
    }

    @Test("A throw message carries the throw, not an image")
    func throwPayloadIsAWord() throws {
        let data = try PeerMessage.throw(.paper).encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("paper"))
        #expect(!text.contains("png"))
    }

    @Test("Garbage and empty packets decode to nil, not a crash")
    func garbageDecodesToNil() {
        #expect(PeerMessage.decoded(from: Data()) == nil)
        #expect(PeerMessage.decoded(from: Data("not a message".utf8)) == nil)
        #expect(PeerMessage.decoded(from: Data([0x01])) == nil)
    }

    @Test("An unknown message type is rejected")
    func unknownTypeRejected() {
        let json = #"{"type":"explode"}"#
        #expect(PeerMessage.decoded(from: Data(json.utf8)) == nil)
    }
}
