# Changelog

## 2.0.0 — 2026-10-26

Full SwiftUI modernization of the 2023 UIKit game.

> Public export note: this tree is a squashed export of that
> modernization. The original private history — including its
> author identity, the original bundle id, and the junk files
> that were in the original tree — is not included here.

### Changed

- UIKit storyboards, AppDelegate, and SceneDelegate replaced by
  SwiftUI (`RockPaperScissorsApp`, `ContentView`,
  `PeerBrowserView`). The stock `MCBrowserViewController` is
  replaced by a SwiftUI nearby-player list.
- Swift 5.0 to Swift 6.0, Xcode 14.3 project format to Xcode 16
  format, iOS 16.4 deployment target to iOS 17.0.
- Bundle id changed from the original author-named id to
  `com.enonymous1.rockpaperscissors`; the hardcoded development
  team id is removed.
- The countdown is now a typed `CountdownStep` sequence, one
  second per word (ROCK, PAPER, SCISSORS, SHOOT), instead of
  parsing a `DateComponentsFormatter` string with `Int(...)`.
- Throws are chosen with buttons, not image views with tap
  gestures, and scores are labels, not disabled text fields.
- The peer name is a generated `Player-XXXX` label, not the
  device name.
- `NSLocalNetworkUsageDescription` and `NSBonjourServices`
  (`_jpl-rps._tcp`) are now declared; v1 declared neither.

### Fixed

- Scores are actually kept now. v1 declared Wins/Losses/Ties
  outlets and never wrote to them.
- Rounds are actually decided now. v1 only printed a tie to the
  console; v2 computes win/lose/tie for all nine matchups and
  updates the score.
- Play Again exists. v1 hid the Play button permanently after
  the first round, so the game was one round long.
- The countdown timer is cancelled on disconnect, rematch, and
  deinit. v1's timer was never invalidated and could fire
  repeatedly at SHOOT, re-sending throws.
- Send failures are surfaced as an alert instead of swallowed
  with `try?`, and an empty or garbage packet decodes to nil
  instead of crashing on `data[0]`.
- Disconnects reset the round and re-advertise, instead of
  stranding the UI. The view model also handles a
  user-initiated disconnect separately from a peer dropping.
- Not picking before SHOOT still defaults to Rock, as in v1,
  but now the UI says so.

### Added

- `GameEngine` (pure outcome + score rules) and `PeerMessage`
  (typed Codable messages: play, throw, rematch), replacing
  v1's raw Bool byte and PNG-over-the-wire protocol. The
  `jpl-rps` service type is unchanged, so the concept of the
  game is the same; the wire format is not compatible with v1.
- `MultipeerSession` wrapper behind a `PeerSessionProtocol`,
  so the view model is testable without two devices.
- Swift Testing suites: game rules (all nine matchups, score
  columns), peer-message round-trips and garbage rejection,
  and view-model play/rematch/disconnect/invitation flows.
  The countdown itself is timing and is not unit-tested; the
  resolution it triggers is, via a test helper.
- Real app icon (all 17 slots, built from the original
  scissors artwork on an iOS-blue background) and a real accent
  color. v1's icon was a placeholder with no file and its
  accent color was empty.
- GitHub Actions CI (SwiftLint + simulator build/test),
  SwiftLint config, MIT LICENSE, and `.gitattributes` with
  `eol=lf` so Windows checkouts stop showing every file as
  modified.

### Removed

- The CoreDataIntro sample project and seven `um150mx`
  installer PDFs (~3.3 MB) that were committed inside
  `Assets.xcassets` but never referenced by the target.
- The storyboards, AppDelegate, SceneDelegate, and the old
  Info.plist. The generated Info.plist now carries only the
  privacy and orientation keys from the target settings.

### Not verified locally

There is no Xcode or Swift toolchain on the Linux box this was
built on, so the build gate is CI plus Xcode on a Mac after
push. Multiplayer also needs two physical devices; simulator
discovery is unreliable for MultipeerConnectivity.
