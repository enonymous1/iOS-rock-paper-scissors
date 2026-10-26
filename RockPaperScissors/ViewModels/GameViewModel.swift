import Foundation
import Observation

/// One word of the countdown. v1 derived these from a
/// `DateComponentsFormatter` string parsed with `Int(...)`, so the
/// countdown only worked when the formatter happened to produce a
/// bare number; here the steps are an enum, in order, by design.
enum CountdownStep: CaseIterable, Equatable {
    case rock
    case paper
    case scissors
    case shoot

    var label: String {
        switch self {
        case .rock: return "ROCK"
        case .paper: return "PAPER"
        case .scissors: return "SCISSORS"
        case .shoot: return "SHOOT"
        }
    }
}

/// The whole game state, separated from both SwiftUI and
/// MultipeerConnectivity so it can be tested with a fake session.
///
/// Flow, preserved from v1: Find Match connects two devices, both
/// press Play, then a countdown runs and each side sends its throw
/// at SHOOT. What v1 could not do, v2 can: keep score, resolve a
/// winner, and play another round.
@Observable
final class GameViewModel {
    private(set) var isConnected = false
    private(set) var isBrowsing = false
    private(set) var discoveredPeers: [DiscoveredPeer] = []
    private(set) var pendingInvitation: DiscoveredPeer?
    private(set) var playerReady = false
    private(set) var opponentReady = false
    private(set) var countdownStep: CountdownStep?
    private(set) var playerThrow: Throw?
    private(set) var opponentThrow: Throw?
    private(set) var lastResult: RoundResult?
    private(set) var score = Score()
    private(set) var status = "No opponent yet — find a match."
    private(set) var errorMessage: String?
    private(set) var playerThrowWasDefaulted = false

    var isCountingDown: Bool { countdownStep != nil }

    var canPlay: Bool {
        isConnected && !playerReady && !isCountingDown && lastResult == nil
    }

    var canPlayAgain: Bool {
        isConnected && lastResult != nil && !isCountingDown
    }

    var canChooseThrow: Bool {
        isCountingDown && playerThrow == nil
    }

    private let session: PeerSessionProtocol
    private var countdownTask: Task<Void, Never>?
    private var userInitiatedDisconnect = false

    init(session: PeerSessionProtocol) {
        self.session = session
        session.onMessage = { [weak self] message in
            self?.receive(message)
        }
        session.onConnected = { [weak self] in
            self?.handleConnected()
        }
        session.onDisconnected = { [weak self] in
            self?.handleDisconnected()
        }
        session.onPeersChanged = { [weak self] peers in
            self?.discoveredPeers = peers
        }
        session.onInvitation = { [weak self] peer in
            self?.pendingInvitation = peer
        }
        session.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    /// Starts advertising so a nearby device can find this one.
    /// Called from the view's `onAppear`, not from `init`, so tests
    /// can build a view model without touching the radio.
    func start() {
        session.startAdvertising()
    }

    func findMatch() {
        isBrowsing = true
        session.startBrowsing()
    }

    func stopBrowsing() {
        isBrowsing = false
        session.stopBrowsing()
    }

    func invite(_ peer: DiscoveredPeer) {
        stopBrowsing()
        status = "Connecting…"
        session.invite(peer)
    }

    func answerInvitation(accept: Bool) {
        pendingInvitation = nil
        session.respondToInvitation(accept: accept)
    }

    func dismissError() {
        errorMessage = nil
    }

    func playPressed() {
        guard isConnected, !playerReady, lastResult == nil else { return }
        playerReady = true
        status = opponentReady ? "Get ready…" : "Waiting for opponent…"
        send(.play)
        if opponentReady {
            startCountdown()
        }
    }

    func playAgainPressed() {
        guard isConnected, lastResult != nil else { return }
        resetRound()
        playerReady = true
        status = opponentReady ? "Get ready…" : "Waiting for opponent…"
        send(.rematch)
        if opponentReady {
            startCountdown()
        }
    }

    func chooseThrow(_ throw: Throw) {
        guard canChooseThrow else { return }
        playerThrow = throw
    }

    func disconnect() {
        cancelCountdown()
        userInitiatedDisconnect = true
        session.disconnect()
        resetRound()
        isConnected = false
        status = "Disconnected."
    }

    // MARK: - Test support

    /// Sets both throws and resolves, bypassing the countdown.
    /// The countdown itself is timing, not logic, so it is not
    /// unit-tested; the resolution it triggers is, through here.
    func applyThrowsForTesting(player: Throw, opponent: Throw) {
        playerThrow = player
        opponentThrow = opponent
        resolveRound()
    }

    // MARK: - Incoming messages

    private func receive(_ message: PeerMessage) {
        switch message {
        case .play:
            opponentReady = true
            if playerReady {
                status = "Get ready…"
                startCountdown()
            } else {
                status = "Opponent is ready — press Play."
            }
        case .throw(let value):
            opponentThrow = value
            if playerThrow != nil {
                resolveRound()
            }
        case .rematch:
            let wasReady = playerReady
            resetRound()
            playerReady = wasReady
            opponentReady = true
            if playerReady {
                status = "Get ready…"
                startCountdown()
            } else {
                status = "Opponent wants a rematch — press Play Again."
            }
        }
    }

    private func handleConnected() {
        isConnected = true
        isBrowsing = false
        session.stopBrowsing()
        resetRound()
        status = "Opponent found — press Play."
    }

    private func handleDisconnected() {
        cancelCountdown()
        isConnected = false
        isBrowsing = false
        resetRound()
        if userInitiatedDisconnect {
            // disconnect() already set the status; only re-advertise
            // so a later Find Match can still find this device.
            userInitiatedDisconnect = false
            status = "Disconnected."
            session.startAdvertising()
            return
        }
        status = "Opponent disconnected."
        // Advertise again so the next Find Match can find us;
        // this does not reconnect automatically.
        session.startAdvertising()
    }

    // MARK: - Countdown and resolution

    private func startCountdown() {
        cancelCountdown()
        countdownTask = Task { [weak self] in
            for step in CountdownStep.allCases {
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    self.countdownStep = step
                    if step == .shoot {
                        self.shoot()
                    }
                }
                if step != .shoot {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            await MainActor.run { [weak self] in
                self?.countdownStep = nil
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownStep = nil
    }

    /// Sends the player's throw at SHOOT. v1 silently defaulted to
    /// rock when nothing had been picked; v2 keeps that behaviour
    /// (a round must resolve) but says so in the UI.
    private func shoot() {
        if playerThrow == nil {
            playerThrow = .rock
            playerThrowWasDefaulted = true
        }
        send(.throw(playerThrow!))
        if opponentThrow != nil {
            resolveRound()
        }
    }

    private func resolveRound() {
        guard let player = playerThrow, let opponent = opponentThrow else { return }
        let result = GameEngine.outcome(player: player, opponent: opponent)
        lastResult = result
        score = GameEngine.applying(result, to: score)
        status = result.label
    }

    private func resetRound() {
        cancelCountdown()
        playerReady = false
        opponentReady = false
        playerThrow = nil
        opponentThrow = nil
        lastResult = nil
        playerThrowWasDefaulted = false
    }

    private func send(_ message: PeerMessage) {
        do {
            try session.send(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
