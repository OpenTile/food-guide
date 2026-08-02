// © 2026 Andrei Chenchik. All rights reserved.
// Unauthorized using, copying, distribution, or modification prohibited.

import ComposableArchitecture
import Testing
@testable import FoodGuide

@MainActor
struct AppFeatureTests {
    enum TestFailure: Error {
        case unexpectedToken
    }

    @Test
    func firstLaunchWithoutStoredTokenRequiresOnboarding() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].load = { nil }
        }

        await store.send(.task)
        await store.receive(\.storedTokenMissing) {
            $0.screen = .onboarding
        }
    }

    @Test
    func storageReadFailureShowsOnboardingError() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].load = {
                throw TestFailure.unexpectedToken
            }
        }

        await store.send(.task)
        await store.receive(\.tokenLoadFailed) {
            $0.errorMessage = "Couldn’t read the saved token. Enter it again."
            $0.screen = .onboarding
        }
    }

    @Test
    func subsequentLaunchWithStoredTokenShowsMainScreen() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].load = { "test-token" }
        }

        await store.send(.task)
        await store.receive(\.storedTokenFound) {
            $0.screen = .main
        }
    }

    @Test
    func blankTokenCannotReachMainScreen() async {
        var state = AppFeature.State()
        state.screen = .onboarding
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.tokenChanged(" \n")) {
            $0.token = " \n"
        }
        await store.send(.continueButtonTapped)
    }

    @Test
    func suppliedTokenIsStoredBeforeShowingMainScreen() async {
        var state = AppFeature.State()
        state.screen = .onboarding
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].save = { token in
                guard token == "test-token" else { throw TestFailure.unexpectedToken }
            }
        }

        await store.send(.tokenChanged(" test-token\n")) {
            $0.token = " test-token\n"
        }
        await store.send(.continueButtonTapped)
        await store.receive(\.tokenSaved) {
            $0.screen = .main
            $0.token = ""
        }
    }

    @Test
    func storageFailureKeepsTokenOnOnboardingScreen() async {
        var state = AppFeature.State()
        state.screen = .onboarding
        state.token = "test-token"
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].save = { _ in
                throw TestFailure.unexpectedToken
            }
        }

        await store.send(.continueButtonTapped)
        await store.receive(\.tokenSaveFailed) {
            $0.errorMessage = "Couldn’t save the token securely. Try again."
        }
    }
}
