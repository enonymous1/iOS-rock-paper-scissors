import SwiftUI

/// The whole game screen, replacing v1's storyboard.
///
/// Layout follows v1's: score at the top, the two throws in the
/// middle (opponent's flipped, as in v1), status and countdown
/// below, then the three choices. The differences are all
/// behaviour: score is a label, not a disabled text field; the
/// choices are buttons, not image views with tap gestures, so
/// VoiceOver and keyboard users can actually pick a throw; and
/// there is a Play Again button, which v1 never had.
struct ContentView: View {
    @State private var viewModel = GameViewModel(session: MultipeerSession())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scoreRow

                    HStack(spacing: 32) {
                        throwColumn(
                            title: "Opponent",
                            imageName: viewModel.opponentThrow?.imageName,
                            flipped: true
                        )
                        throwColumn(
                            title: "You",
                            imageName: viewModel.playerThrow?.imageName,
                            flipped: false
                        )
                    }

                    VStack(spacing: 8) {
                        Text(viewModel.status)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("statusLabel")
                        if let step = viewModel.countdownStep {
                            Text(step.label)
                                .font(.largeTitle.bold())
                                .accessibilityLabel("Countdown: \(step.label)")
                        }
                        if let result = viewModel.lastResult {
                            Text(result.label)
                                .font(.title2.bold())
                            if viewModel.playerThrowWasDefaulted {
                                Text("No throw picked — defaulted to Rock.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    actions

                    if viewModel.isCountingDown || viewModel.lastResult != nil {
                        choiceRow
                    }
                }
                .padding()
            }
            .navigationTitle("Rock Paper Scissors")
            .toolbar {
                if viewModel.isConnected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect") {
                            viewModel.disconnect()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.start()
            }
            .sheet(isPresented: browserBinding) {
                PeerBrowserView(
                    peers: viewModel.discoveredPeers,
                    onInvite: { viewModel.invite($0) },
                    onCancel: { viewModel.stopBrowsing() }
                )
            }
            .alert(
                "Incoming connection",
                isPresented: invitationBinding,
                presenting: viewModel.pendingInvitation
            ) { peer in
                Button("Accept") {
                    viewModel.answerInvitation(accept: true)
                }
                Button("Decline", role: .destructive) {
                    viewModel.answerInvitation(accept: false)
                }
            } message: { peer in
                Text("\(peer.displayName) wants to play. Accept?")
            }
            .alert(
                "Something went wrong",
                isPresented: errorBinding,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: { message in
                Text(message)
            }
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 24) {
            scoreCell(label: "Wins", value: viewModel.score.wins)
            scoreCell(label: "Losses", value: viewModel.score.losses)
            scoreCell(label: "Ties", value: viewModel.score.ties)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Score: \(viewModel.score.wins) wins, "
                + "\(viewModel.score.losses) losses, "
                + "\(viewModel.score.ties) ties"
        )
    }

    private func scoreCell(label: String, value: Int) -> some View {
        VStack {
            Text("\(value)").font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func throwColumn(
        title: String,
        imageName: String?,
        flipped: Bool
    ) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .rotationEffect(flipped ? .degrees(180) : .degrees(0))
                    .scaleEffect(x: flipped ? -1 : 1, y: 1)
                    .accessibilityLabel("\(title) threw \(imageName)")
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .frame(width: 120, height: 120)
                    .accessibilityLabel("\(title) has not thrown yet")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if !viewModel.isConnected {
                Button("Find a Match") {
                    viewModel.findMatch()
                }
                .buttonStyle(.borderedProminent)
            }
            if viewModel.canPlay {
                Button("Play") {
                    viewModel.playPressed()
                }
                .buttonStyle(.borderedProminent)
            }
            if viewModel.canPlayAgain {
                Button("Play Again") {
                    viewModel.playAgainPressed()
                }
                .buttonStyle(.borderedProminent)
            }
            if viewModel.playerReady && !viewModel.opponentReady
                && !viewModel.isCountingDown && viewModel.lastResult == nil {
                Text("Waiting for opponent…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var choiceRow: some View {
        HStack(spacing: 24) {
            ForEach(Throw.allCases, id: \.self) { value in
                Button {
                    viewModel.chooseThrow(value)
                } label: {
                    Image(value.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .opacity(
                            viewModel.playerThrow == nil
                                || viewModel.playerThrow == value ? 1 : 0.35
                        )
                }
                .disabled(!viewModel.canChooseThrow)
                .accessibilityLabel("Throw \(value.rawValue)")
            }
        }
    }

    private var browserBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isBrowsing },
            set: { if !$0 { viewModel.stopBrowsing() } }
        )
    }

    private var invitationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingInvitation != nil },
            set: { if !$0 { viewModel.answerInvitation(accept: false) } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}
