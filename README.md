# Rock Paper Scissors

A two-player Rock Paper Scissors game for iOS, played between two
nearby devices over MultipeerConnectivity. No server, no account,
no internet matchmaking: open the app on two phones, find each
other, and play.

> Public export note: this repository is a squashed export of
> the v2.0.0 modernization. The original private history is not
> included, and the Xcode project, target, and scheme stay
> `RockPaperScissors` — only the repository folder was renamed.

## How it works

1. Launch the app on two nearby iOS devices.
2. One player taps **Find a Match** and taps the other device in
   the list. (The other device gets an accept/decline prompt.)
3. Both players tap **Play**.
4. A ROCK / PAPER / SCISSORS / SHOOT countdown runs. Pick a throw
   during the countdown; at SHOOT both throws are exchanged and
   the round is scored.
5. Tap **Play Again** for the next round. The score carries over
   until you disconnect.

If you don't pick before SHOOT, the game defaults to Rock and
says so, rather than leaving the round hanging the way v1 did.

## Tech stack

- Swift 6, SwiftUI, `@Observable` view model
- MultipeerConnectivity (`jpl-rps` service type, unchanged from v1)
- iOS 17.0 or later, Xcode 16 or newer
- Swift Testing, SwiftLint, GitHub Actions CI
- No third-party packages

## Project structure

```text
RockPaperScissors/
├── RockPaperScissors.xcodeproj/
├── RockPaperScissors/
│   ├── RockPaperScissorsApp.swift   # @main, replaces AppDelegate/SceneDelegate
│   ├── Models/
│   │   ├── Throw.swift              # throw enum + beats rules
│   │   ├── GameEngine.swift         # pure outcome + score logic
│   │   └── PeerMessage.swift        # typed wire messages (Codable)
│   ├── Services/
│   │   └── PeerSession.swift        # MultipeerConnectivity wrapper
│   ├── ViewModels/
│   │   └── GameViewModel.swift      # connection + countdown + round state
│   ├── Views/
│   │   ├── ContentView.swift        # game screen
│   │   └── PeerBrowserView.swift    # nearby-player list
│   └── Assets.xcassets/             # original rock/paper/scissors art + app icon
├── RockPaperScissorsTests/          # Swift Testing suites
├── .github/workflows/ios.yml
├── .swiftlint.yml
├── CHANGELOG.md
└── LICENSE
```

The rules, the wire format, and the UI are three separate pieces
now. `GameEngine` and `PeerMessage` have no UI or networking in
them at all, which is why they can be unit-tested without a
second device.

## Requirements

- macOS with Xcode 16 or newer
- Two nearby iOS devices for real multiplayer testing. The
  simulator can build and run the app, but nearby peer discovery
  is not reliable in the simulator, so a real two-device test is
  still the gate for the multiplayer flow.
- A valid Apple development team under **Signing & Capabilities**
  for installing on physical devices. No team id is committed:
  v1 hardcoded one, and it has been removed.

## Setup

```bash
git clone https://github.com/enonymous1/rock-paper-scissors.git
cd rock-paper-scissors
open RockPaperScissors.xcodeproj
```

Select the `RockPaperScissors` target, set your development
team, and build/run on an iOS 17+ device or simulator.

From the command line, on macOS with Xcode installed:

```bash
xcodebuild -project RockPaperScissors.xcodeproj \
  -scheme RockPaperScissors \
  -sdk iphonesimulator \
  -configuration Debug build
```

## Privacy

- The local-network permission prompt comes from
  `NSLocalNetworkUsageDescription`, and the Bonjour service
  (`_jpl-rps._tcp`) is declared in `NSBonjourServices`. Both are
  set in the target's build settings and land in the generated
  Info.plist. v1 declared neither.
- Your peer name in the browser list is a generated
  `Player-XXXX` label, not your device name, which v1 broadcast
  to every nearby peer.

## Limitations

- Two-player, nearby only. There is no internet matchmaking,
  no lobby, and no saved score history; disconnecting ends the
  match (the score is kept if you reconnect in the same session,
  but it is not persisted).
- The countdown is one second per word, four seconds total,
  down from v1's seven-second timer.

## License

MIT. See [LICENSE](LICENSE).
