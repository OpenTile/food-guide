// © 2026 Andrei Chenchik. All rights reserved.
// Unauthorized using, copying, distribution, or modification prohibited.

import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        enum Screen: Equatable {
            case launching
            case main
            case onboarding
        }

        var errorMessage: String?
        var screen = Screen.launching
        var token = ""

        var canContinue: Bool {
            !normalizedToken.isEmpty
        }

        var normalizedToken: String {
            token.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    enum Action {
        case continueButtonTapped
        case storedTokenFound
        case storedTokenMissing
        case task
        case tokenChanged(String)
        case tokenLoadFailed
        case tokenSaveFailed
        case tokenSaved
    }

    @Dependency(TokenStorageClient.self) private var tokenStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .continueButtonTapped:
                guard state.canContinue else { return .none }
                let token = state.normalizedToken
                return .run { [tokenStorage] send in
                    do {
                        try tokenStorage.save(token)
                        await send(.tokenSaved)
                    } catch {
                        await send(.tokenSaveFailed)
                    }
                }

            case .storedTokenFound:
                state.errorMessage = nil
                state.screen = .main
                return .none

            case .storedTokenMissing:
                state.errorMessage = nil
                state.screen = .onboarding
                return .none

            case .task:
                guard state.screen == .launching else { return .none }
                return .run { [tokenStorage] send in
                    do {
                        if try tokenStorage.load() == nil {
                            await send(.storedTokenMissing)
                        } else {
                            await send(.storedTokenFound)
                        }
                    } catch {
                        await send(.tokenLoadFailed)
                    }
                }

            case .tokenChanged(let token):
                state.errorMessage = nil
                state.token = token
                return .none

            case .tokenLoadFailed:
                state.errorMessage = "Couldn’t read the saved token. Enter it again."
                state.screen = .onboarding
                return .none

            case .tokenSaveFailed:
                state.errorMessage = "Couldn’t save the token securely. Try again."
                return .none

            case .tokenSaved:
                state.errorMessage = nil
                state.screen = .main
                state.token = ""
                return .none
            }
        }
    }
}
