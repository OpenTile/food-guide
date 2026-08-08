import ComposableArchitecture
import Foundation

@Reducer
struct EntriesFeature {
    @ObservableState
    struct State: Equatable {
        enum LoadState: Equatable {
            case failed(String)
            case initial
            case loaded
            case loading
        }

        enum SaveState: Equatable {
            case failed(SaveError)
            case idle
            case saving
        }

        var deleteError: DeleteError?
        var deletingEntryID: Entry.ID?
        var draft = Draft()
        var entries: [Entry] = []
        var entryIDsAcceptedWhileLoading: Set<Entry.ID> = []
        var entryIDsDeletedWhileLoading: Set<Entry.ID> = []
        var loadState = LoadState.initial
        var saveState = SaveState.idle

        var canSend: Bool {
            saveState != .saving && draft.canSubmit
        }
    }

    enum Action {
        case appDidBecomeActive
        case deleteButtonTapped(Entry.ID)
        case deleteResponse(Result<Entry.ID, DeleteError>)
        case draftChanged(String)
        case entryResponse(Result<Entry, SaveError>)
        case entriesResponse(Result<[Entry], LoadError>)
        case refreshRequested
        case sendButtonTapped
        case task
    }

    enum DeleteError: Error, Equatable {
        case requestFailed

        var description: String {
            switch self {
            case .requestFailed:
                "Couldn’t delete your Entry. Try again."
            }
        }
    }

    enum LoadError: Error, Equatable {
        case failed
    }

    enum SaveError: Error, Equatable {
        case requestFailed

        var description: String {
            switch self {
            case .requestFailed:
                "Couldn’t save your Draft. Try again."
            }
        }
    }

    @Dependency(\.calendar) private var calendar
    @Dependency(\.date.now) private var now
    @Dependency(EntryClient.self) private var entryClient
    @Dependency(TokenStorageClient.self) private var tokenStorage
    @Dependency(\.uuid) private var uuid

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped(let entryID):
                guard
                    state.deletingEntryID == nil,
                    state.entries.contains(where: { $0.id == entryID })
                else { return .none }
                state.deleteError = nil
                state.deletingEntryID = entryID
                return .run { [entryClient, tokenStorage] send in
                    await send(
                        .deleteResponse(
                            await Result {
                                guard let token = try tokenStorage.load() else {
                                    throw DeleteError.requestFailed
                                }
                                try await entryClient.delete(entryID, token)
                                return entryID
                            }
                            .mapError { _ in DeleteError.requestFailed }
                        )
                    )
                }

            case .deleteResponse(.failure(let error)):
                state.deleteError = error
                state.deletingEntryID = nil
                return .none

            case .deleteResponse(.success(let entryID)):
                state.deletingEntryID = nil
                state.entries.removeAll { $0.id == entryID }
                if state.loadState == .loading {
                    state.entryIDsDeletedWhileLoading.insert(entryID)
                }
                return .none

            case .draftChanged(let draft):
                state.draft.updateText(draft)
                if case .failed = state.saveState {
                    state.saveState = .idle
                }
                return .none

            case .entryResponse(.failure(let error)):
                state.saveState = .failed(error)
                return .none

            case .entryResponse(.success(let entry)):
                state.draft.accept(entry)
                if let index = state.entries.firstIndex(where: { $0.id == entry.id }) {
                    state.entries[index] = entry
                } else {
                    state.entries.append(entry)
                }
                state.entries.sort { $0.eatenAt < $1.eatenAt }
                if state.loadState == .loading {
                    state.entryIDsAcceptedWhileLoading.insert(entry.id)
                }
                state.saveState = .idle
                return .none

            case .entriesResponse(.failure):
                state.entryIDsAcceptedWhileLoading = []
                state.entryIDsDeletedWhileLoading = []
                state.loadState = .failed("Couldn’t load your Entries. Try again.")
                return .none

            case .entriesResponse(.success(let entries)):
                let acceptedEntries = state.entries.filter {
                    state.entryIDsAcceptedWhileLoading.contains($0.id)
                }
                state.entries = entries.filter {
                    !state.entryIDsDeletedWhileLoading.contains($0.id)
                }
                for entry in acceptedEntries where !state.entries.contains(where: { $0.id == entry.id }) {
                    state.entries.append(entry)
                }
                state.entries.sort { $0.eatenAt < $1.eatenAt }
                state.entryIDsAcceptedWhileLoading = []
                state.entryIDsDeletedWhileLoading = []
                state.loadState = .loaded
                return .none

            case .appDidBecomeActive, .refreshRequested, .task:
                state.entryIDsAcceptedWhileLoading = []
                state.entryIDsDeletedWhileLoading = []
                state.loadState = .loading
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

            case .sendButtonTapped:
                guard state.canSend else { return .none }
                let submission = state.draft.prepareSubmission(id: uuid(), eatenAt: now)
                state.saveState = .saving
                return .run { [entryClient, tokenStorage] send in
                    await send(
                        .entryResponse(
                            await Result {
                                guard let token = try tokenStorage.load() else {
                                    throw SaveError.requestFailed
                                }
                                return try await entryClient.create(submission, token)
                            }
                            .mapError { _ in SaveError.requestFailed }
                        )
                    )
                }
            }
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case load
    }
}
