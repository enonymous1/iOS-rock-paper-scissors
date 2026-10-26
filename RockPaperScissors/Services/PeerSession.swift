import Foundation
import MultipeerConnectivity

/// A nearby player discovered by the browser. Only the display name
/// and a stable id cross into the view model; the underlying
/// `MCPeerID` stays inside the real session, so tests and SwiftUI
/// never have to handle a Multipeer object.
struct DiscoveredPeer: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
}

/// The peer-to-peer session, behind a protocol so the view model
/// can be tested with a fake instead of two real devices.
///
/// All callbacks are invoked on the main queue: Multipeer delegate
/// methods arrive on background threads, and v1 updated UIKit from
/// them only by accident of timing in some paths. The real session
/// hops to the main queue before every callback; the fake in tests
/// calls them synchronously, which is also main-thread in tests.
protocol PeerSessionProtocol: AnyObject {
    var onMessage: ((PeerMessage) -> Void)? { get set }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onPeersChanged: (([DiscoveredPeer]) -> Void)? { get set }
    var onInvitation: ((DiscoveredPeer) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    func startAdvertising()
    func stopAdvertising()
    func startBrowsing()
    func stopBrowsing()
    func invite(_ peer: DiscoveredPeer)
    func respondToInvitation(accept: Bool)
    func send(_ message: PeerMessage) throws
    func disconnect()
}

/// Errors surfaced to the UI instead of v1's silent `try?`.
enum PeerSessionError: LocalizedError {
    case noConnectedPeer
    case notConnected

    var errorDescription: String? {
        switch self {
        case .noConnectedPeer:
            return "No opponent is connected yet."
        case .notConnected:
            return "The peer session is not connected."
        }
    }
}

/// MultipeerConnectivity wrapper.
///
/// Differences from v1, all deliberate:
/// - The peer name is a generated "Player-XXXX" label, not the
///   device name, which v1 broadcast to every nearby peer.
/// - Advertising starts on demand and stops on disconnect, instead
///   of running from launch until the app dies.
/// - The invitation handler is stored and answered by the view
///   model, so declining no longer passes the session to a handler
///   that expected an acceptance.
/// - Sending uses `PeerMessage`, never a raw Bool byte or a PNG.
final class MultipeerSession: NSObject, PeerSessionProtocol {
    static let serviceType = "jpl-rps"

    var onMessage: ((PeerMessage) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onPeersChanged: (([DiscoveredPeer]) -> Void)?
    var onInvitation: ((DiscoveredPeer) -> Void)?
    var onError: ((String) -> Void)?

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser?
    private var discovered: [MCPeerID] = []
    private var pendingInvitation: ((Bool, MCSession?) -> Void)?

    override init() {
        // Four hex digits are enough to tell two "Player" labels
        // apart in the browser list without exposing anything about
        // the device itself.
        let suffix = String(format: "%04X", Int.random(in: 0...0xFFFF))
        peerID = MCPeerID(displayName: "Player-\(suffix)")
        session = MCSession(peer: peerID)
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
    }

    func startBrowsing() {
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discovered = []
        publishPeers()
    }

    func invite(_ peer: DiscoveredPeer) {
        guard let target = discovered.first(where: { $0.displayName == peer.displayName }) else {
            return
        }
        browser?.invitePeer(target, to: session, withContext: nil, timeout: 30)
    }

    func respondToInvitation(accept: Bool) {
        let handler = pendingInvitation
        pendingInvitation = nil
        handler?(accept, accept ? session : nil)
    }

    func send(_ message: PeerMessage) throws {
        guard !session.connectedPeers.isEmpty else {
            throw PeerSessionError.noConnectedPeer
        }
        try session.send(
            message.encoded(),
            toPeers: session.connectedPeers,
            with: .reliable
        )
    }

    func disconnect() {
        stopBrowsing()
        stopAdvertising()
        session.disconnect()
    }

    private func publishPeers() {
        let peers = discovered.map {
            DiscoveredPeer(id: $0.displayName, displayName: $0.displayName)
        }
        DispatchQueue.main.async { [weak self] in
            self?.onPeersChanged?(peers)
        }
    }

    private func reportError(_ error: Error) {
        let message = error.localizedDescription
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }
}

extension MultipeerSession: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.onConnected?()
            case .notConnected:
                self.onDisconnected?()
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        guard let message = PeerMessage.decoded(from: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Received a message that could not be understood.")
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(message)
        }
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        if let error {
            reportError(error)
        }
    }
}

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        pendingInvitation = invitationHandler
        let peer = DiscoveredPeer(id: peerID.displayName, displayName: peerID.displayName)
        DispatchQueue.main.async { [weak self] in
            self?.onInvitation?(peer)
        }
    }
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard !discovered.contains(peerID) else { return }
        discovered.append(peerID)
        publishPeers()
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discovered.removeAll { $0 == peerID }
        publishPeers()
    }
}
