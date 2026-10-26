import Testing

@testable import RockPaperScissors

@Suite("Game rules")
struct GameEngineTests {
    @Test("Every throw beats exactly one throw and loses to one")
    func beatsCycle() {
        #expect(Throw.rock.beats(.scissors))
        #expect(Throw.scissors.beats(.paper))
        #expect(Throw.paper.beats(.rock))
        #expect(!Throw.rock.beats(.paper))
        #expect(!Throw.paper.beats(.scissors))
        #expect(!Throw.scissors.beats(.rock))
    }

    @Test("All nine matchups resolve correctly")
    func allMatchups() {
        let wins: [(Throw, Throw)] = [
            (.rock, .scissors), (.scissors, .paper), (.paper, .rock),
        ]
        for (player, opponent) in wins {
            #expect(GameEngine.outcome(player: player, opponent: opponent) == .win)
            #expect(GameEngine.outcome(player: opponent, opponent: player) == .lose)
        }
        for value in Throw.allCases {
            #expect(GameEngine.outcome(player: value, opponent: value) == .tie)
        }
    }

    @Test("A result increments only its own score column")
    func scoreColumns() {
        let base = Score(wins: 1, losses: 2, ties: 3)
        #expect(GameEngine.applying(.win, to: base) == Score(wins: 2, losses: 2, ties: 3))
        #expect(GameEngine.applying(.lose, to: base) == Score(wins: 1, losses: 3, ties: 3))
        #expect(GameEngine.applying(.tie, to: base) == Score(wins: 1, losses: 2, ties: 4))
    }
}
