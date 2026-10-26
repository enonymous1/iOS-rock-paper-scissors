import Testing

@testable import RockPaperScissors

/// Stand-in for MultipeerConnectivity: records what the view model
/// sends and lets a test drive the other side's messages, so no
/// test needs two devices.
final class FakePeerSession: PeerSessionProtocol {
    var onMessage: ((PeerMessage) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onPeersChanged: (([DiscoveredPeer]) -> Void)?
    var onInvitation: ((DiscoveredPeer) -> Void)?
    var onError: ((String) -> Void)?

    var sent: [PeerMessage] = []
    var advertisingStarts = 0
    var browsingStarts = 0
    var invited: [DiscoveredPeer] = []
    var invitationAnswers: [Bool] = []

    func startAdvertising() { advertisingStarts += 1 }
    func stopAdvertising() {}
    func startBrowsing() { browsingStarts += 1 }
    func stopBrowsing() {}
    func invite(_ peer: DiscoveredPeer) { invited.append(peer) }
    func respondToInvitation(accept: Bool) { invitationAnswers.append(accept) }
    func send(_ message: PeerMessage) throws { sent.append(message) }
    func disconnect() { onDisconnected?() }

    func simulateConnected() { onConnected?() }
    func simulateDisconnected() { onDisconnected?() }
    func simulateMessage(_ message: PeerMessage) { onMessage?(message) }
    func simulateInvitation(from peer: DiscoveredPeer) { onInvitation?(peer) }
}

@MainActor
@Suite("Game view model")
struct GameViewModelTests {
    private func connectedViewModel() -> (GameViewModel, FakePeerSession) {
        let session = FakePeerSession()
        let viewModel = GameViewModel(session: session)
        session.simulateConnected()
        return (viewModel, session)
    }

    @Test("Connecting shows the Play prompt and clears any old round")
    func connectedState() {
        let (viewModel, _) = connectedViewModel()
        #expect(viewModel.isConnected)
        #expect(viewModel.status == "Opponent found — press Play.")
        #expect(viewModel.canPlay)
    }

    @Test("Play sends a play message and waits for the opponent")
    func playWaitsForOpponent() {
        let (viewModel, session) = connectedViewModel()
        viewModel.playPressed()
        #expect(session.sent == [.play])
        #expect(viewModel.playerReady)
        #expect(!viewModel.isCountingDown)
    }

    @Test("An opponent throw alone does not resolve the round")
    func opponentThrowAloneDoesNotResolve() {
        let (viewModel, session) = connectedViewModel()
        session.simulateMessage(.throw(.paper))
        #expect(viewModel.lastResult == nil)
        #expect(viewModel.score == Score())
    }

    @Test("Both throws resolve the round and update only the right column")
    func bothThrowsResolve() {
        let (viewModel, _) = connectedViewModel()
        viewModel.applyThrowsForTesting(player: .rock, opponent: .scissors)
        #expect(viewModel.lastResult == .win)
        #expect(viewModel.score == Score(wins: 1, losses: 0, ties: 0))
        #expect(viewModel.canPlayAgain)
    }

    @Test("A tie resolves as a tie, not a win or a loss")
    func tieResolvesAsTie() {
        let (viewModel, _) = connectedViewModel()
        viewModel.applyThrowsForTesting(player: .paper, opponent: .paper)
        #expect(viewModel.lastResult == .tie)
        #expect(viewModel.score == Score(wins: 0, losses: 0, ties: 1))
    }

    @Test("A rematch keeps the score and waits for the other side")
    func rematchKeepsScore() {
        let (viewModel, session) = connectedViewModel()
        viewModel.applyThrowsForTesting(player: .rock, opponent: .paper)
        #expect(viewModel.score.losses == 1)
        viewModel.playAgainPressed()
        #expect(session.sent.last == .rematch)
        #expect(viewModel.score.losses == 1)
        #expect(viewModel.lastResult == nil)
        #expect(viewModel.playerReady)
    }

    @Test("Disconnect clears the connection but the score survives a reconnect")
    func disconnectKeepsScoreForReconnect() {
        let (viewModel, session) = connectedViewModel()
        viewModel.applyThrowsForTesting(player: .scissors, opponent: .paper)
        session.simulateDisconnected()
        #expect(!viewModel.isConnected)
        #expect(viewModel.status == "Opponent disconnected.")
        session.simulateConnected()
        #expect(viewModel.isConnected)
        #expect(viewModel.score.wins == 1)
    }

    @Test("Answering an invitation forwards the answer to the session")
    func invitationAnswerForwarded() {
        let session = FakePeerSession()
        let viewModel = GameViewModel(session: session)
        let peer = DiscoveredPeer(id: "Player-1234", displayName: "Player-1234")
        session.simulateInvitation(from: peer)
        #expect(viewModel.pendingInvitation == peer)
        viewModel.answerInvitation(accept: true)
        #expect(session.invitationAnswers == [true])
        #expect(viewModel.pendingInvitation == nil)
    }
}
