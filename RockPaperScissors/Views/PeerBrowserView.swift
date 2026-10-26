import SwiftUI

/// The nearby-player list. v1 used Apple's stock
/// `MCBrowserViewController`; v2 lists discovered peers in SwiftUI
/// so the sheet, the empty state, and the accessibility labels are
/// the app's own, and inviting a peer is one tap on a row.
struct PeerBrowserView: View {
    let peers: [DiscoveredPeer]
    let onInvite: (DiscoveredPeer) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if peers.isEmpty {
                    ContentUnavailableView(
                        "Looking for nearby players…",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text(
                            "Make sure the other device has the app open and is nearby."
                        )
                    )
                } else {
                    List(peers) { peer in
                        Button {
                            onInvite(peer)
                        } label: {
                            Label(peer.displayName, systemImage: "person")
                        }
                        .accessibilityLabel("Invite \(peer.displayName)")
                    }
                }
            }
            .navigationTitle("Find a Match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
