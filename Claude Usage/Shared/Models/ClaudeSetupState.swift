//
//  ClaudeSetupState.swift
//  Claude Usage
//

enum ClaudeSetupState: Equatable {
    case complete
    case browserOnly
    case terminalOnly
    case none

    static func of(_ profile: Profile) -> ClaudeSetupState {
        let hasBrowserSignIn = profile.hasClaudeAI
        let hasTerminalSignIn = profile.cliCredentialsJSON != nil || profile.hasCliAccount

        switch (hasBrowserSignIn, hasTerminalSignIn) {
        case (true, true):
            return .complete
        case (true, false):
            return .browserOnly
        case (false, true):
            return .terminalOnly
        case (false, false):
            return .none
        }
    }
}
