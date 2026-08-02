import ComposableArchitecture
import CustomDump
import Testing
@testable import FoodGuide

struct BearerTokenTests {
    @Test
    func normalizesWhitespace() {
        expectNoDifference(
            BearerToken(" test-token\n"),
            BearerToken("test-token")
        )
    }

    @Test
    func rejectsBlankValue() {
        expectNoDifference(BearerToken(" \n"), nil)
    }
}

@MainActor
struct AppFeatureTests {
    enum TestFailure: Error {
        case storageFailure
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
                throw TestFailure.storageFailure
            }
        }

        await store.send(.task)
        await store.receive(\.tokenLoadFailed) {
            $0.errorMessage = "Couldn’t read the saved token. Enter it again."
            $0.screen = .onboarding
        }
    }

    @Test
    func subsequentLaunchWithStoredTokenShowsMainScreen() async throws {
        let token = try #require(BearerToken("test-token"))
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].load = { token }
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

        await store.send(.tokenInputChanged(" \n")) {
            $0.tokenInput = " \n"
        }
        await store.send(.continueButtonTapped)
    }

    @Test
    func suppliedTokenIsStoredBeforeShowingMainScreen() async throws {
        let expectedToken = try #require(BearerToken("test-token"))
        var state = AppFeature.State()
        state.screen = .onboarding
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].save = { token in
                guard token == expectedToken else { throw TestFailure.unexpectedToken }
            }
        }

        await store.send(.tokenInputChanged(" test-token\n")) {
            $0.tokenInput = " test-token\n"
        }
        await store.send(.continueButtonTapped)
        await store.receive(\.tokenSaved) {
            $0.screen = .main
            $0.tokenInput = ""
        }
    }

    @Test
    func storageFailureKeepsTokenOnOnboardingScreen() async {
        var state = AppFeature.State()
        state.screen = .onboarding
        state.tokenInput = "test-token"
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0[TokenStorageClient.self].save = { _ in
                throw TestFailure.storageFailure
            }
        }

        await store.send(.continueButtonTapped)
        await store.receive(\.tokenSaveFailed) {
            $0.errorMessage = "Couldn’t save the token securely. Try again."
        }
    }
}
