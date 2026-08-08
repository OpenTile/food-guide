import ComposableArchitecture
import Foundation

@Reducer
struct EntriesFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [Entry] = []
        var hasLoaded = false
        var isLoading = false
        var loadErrorMessage: String?
    }

    enum Action {
        case appDidBecomeActive
        case entriesResponse(Result<[Entry], LoadError>)
        case refreshRequested
        case task
    }

    enum LoadError: Error, Equatable {
        case failed
    }

    @Dependency(\.calendar) private var calendar
    @Dependency(\.date.now) private var now
    @Dependency(EntryClient.self) private var entryClient
    @Dependency(TokenStorageClient.self) private var tokenStorage

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .entriesResponse(.failure):
                state.hasLoaded = true
                state.isLoading = false
                state.loadErrorMessage = "Couldn’t load your Entries. Try again."
                return .none

            case .entriesResponse(.success(let entries)):
                state.entries = entries
                state.hasLoaded = true
                state.isLoading = false
                state.loadErrorMessage = nil
                return .none

            case .appDidBecomeActive, .refreshRequested, .task:
                state.isLoading = true
                state.loadErrorMessage = nil
                let dayWindow = DayWindow(containing: now, calendar: calendar)
                return .run { [entryClient, tokenStorage] send in
                    await send(
                        .entriesResponse(
                            await Result {
                                guard let token = try tokenStorage.load() else {
                                    throw LoadError.failed
                                }
                                return try await entryClient.list(dayWindow, token)
                            }
                            .mapError { _ in LoadError.failed }
                        )
                    )
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)
            }
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case load
    }
}
