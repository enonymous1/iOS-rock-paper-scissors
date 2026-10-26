import Foundation

/// The result of one round, from the local player's point of view.
enum RoundResult: Equatable, Sendable {
    case win
    case lose
    case tie

    /// Short result text for the scoreboard line.
    var label: String {
        switch self {
        case .win: return "You win!"
        case .lose: return "You lose."
        case .tie: return "Tie!"
        }
    }
}

/// The running score. v1 declared score outlets but never wrote to
/// them, so a game could never actually keep score; this struct is
/// the single place a round result turns into a score change.
struct Score: Equatable, Sendable {
    var wins = 0
    var losses = 0
    var ties = 0
}

/// Pure game rules: no UI, no networking, no timers. That is what
/// makes it unit-testable, unlike v1 where the rules lived inside
/// a view controller's timer callback.
struct GameEngine {
    /// Decides a round. Rock beats scissors, scissors beats paper,
    /// paper beats rock; identical throws tie.
    static func outcome(player: Throw, opponent: Throw) -> RoundResult {
        if player == opponent { return .tie }
        return player.beats(opponent) ? .win : .lose
    }

    /// Applies a round result to a score, returning the new score
    /// instead of mutating hidden view-controller state.
    static func applying(_ result: RoundResult, to score: Score) -> Score {
        var next = score
        switch result {
        case .win: next.wins += 1
        case .lose: next.losses += 1
        case .tie: next.ties += 1
        }
        return next
    }
}
