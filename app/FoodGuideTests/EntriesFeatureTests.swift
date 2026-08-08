import ComposableArchitecture
import CustomDump
import Foundation
import Testing
@testable import FoodGuide

@MainActor
struct EntriesFeatureTests {
    private struct DraftFixture {
        let acceptedEntry: Entry
        let submission: DraftSubmission
        let token: BearerToken

        init(
            id: String = "8E1ADDFC-9E9A-4BAF-9A1F-9A7922E3421D",
            text: String = "two eggs, toast, black coffee"
        ) throws {
            let id = try #require(UUID(uuidString: id))
            let eatenAt = Date(timeIntervalSince1970: 1_786_173_300)
            self.acceptedEntry = Entry(id: id, text: text, eatenAt: eatenAt)
            self.submission = DraftSubmission(id: id, text: text, eatenAt: eatenAt)
            self.token = try #require(BearerToken("test-token"))
        }
    }

    private actor EntryCreateGate {
        private var isOpen = false
        private var continuation: CheckedContinuation<Void, Never>?

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation = $0 }
        }
    }

    private actor FailOnceEntryCreator {
        var attempts: [DraftSubmission] = []

        func create(_ submission: DraftSubmission) throws -> Entry {
            attempts.append(submission)
            guard attempts.count > 1 else { throw TestFailure.saveFailed }
            return Entry(
                id: submission.id,
                text: submission.text,
                eatenAt: submission.eatenAt
            )
        }

        func recordedAttempts() -> [DraftSubmission] {
            attempts
        }
    }

    private actor EntryResponses {
        var values: [[Entry]]

        init(_ values: [[Entry]]) {
            self.values = values
        }

        func next() -> [Entry] {
            values.removeFirst()
        }
    }

    enum TestFailure: Error {
        case deleteFailed
        case loadFailed
        case saveFailed
    }

    private func makeStore(
        initialState: EntriesFeature.State? = nil,
        fixture: DraftFixture,
        uuid: UUIDGenerator? = nil,
        create: @escaping @Sendable (DraftSubmission, BearerToken) async throws -> Entry
    ) -> TestStoreOf<EntriesFeature> {
        TestStore(initialState: initialState ?? EntriesFeature.State()) {
            EntriesFeature()
        } withDependencies: {
            $0.date.now = fixture.submission.eatenAt
            $0.uuid = uuid ?? .constant(fixture.submission.id)
            $0[EntryClient.self].create = create
            $0[TokenStorageClient.self].load = { fixture.token }
        }
    }

    @Test
    func sendingDraftAppendsAcceptedEntryAndClearsDraft() async throws {
        let fixture = try DraftFixture()
        let store = makeStore(fixture: fixture) { submission, bearerToken in
            expectNoDifference(submission, fixture.submission)
            expectNoDifference(bearerToken, fixture.token)
            return fixture.acceptedEntry
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.success) {
            $0.draft.text = ""
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
    }

    @Test
    func acceptedEntryRemainsWhenEarlierLoadCompletes() async throws {
        let fixture = try DraftFixture()
        var initialState = EntriesFeature.State()
        initialState.loadState = .loading
        let store = makeStore(initialState: initialState, fixture: fixture) { _, _ in
            fixture.acceptedEntry
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.success) {
            $0.draft.text = ""
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.entryIDsAcceptedWhileLoading = [fixture.acceptedEntry.id]
            $0.saveState = .idle
        }
        await store.send(.entriesResponse(.success([]))) {
            $0.entryIDsAcceptedWhileLoading = []
            $0.loadState = .loaded
        }
    }

    @Test
    func acceptedEntryDoesNotClearANewerDraft() async throws {
        let fixture = try DraftFixture()
        let newerText = "lentil soup"
        let gate = EntryCreateGate()
        let store = makeStore(fixture: fixture) { _, _ in
            await gate.wait()
            return fixture.acceptedEntry
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.send(.draftChanged(newerText)) {
            $0.draft.hasChangedSinceSubmission = true
            $0.draft.text = newerText
        }
        await gate.open()
        await store.receive(\.entryResponse.success) {
            $0.draft.hasChangedSinceSubmission = false
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
    }

    @Test
    func acceptedEntryDoesNotClearANewerDraftWithTheSameText() async throws {
        let fixture = try DraftFixture()
        let gate = EntryCreateGate()
        let store = makeStore(fixture: fixture) { _, _ in
            await gate.wait()
            return fixture.acceptedEntry
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.send(.draftChanged("lentil soup")) {
            $0.draft.hasChangedSinceSubmission = true
            $0.draft.text = "lentil soup"
        }
        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await gate.open()
        await store.receive(\.entryResponse.success) {
            $0.draft.hasChangedSinceSubmission = false
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
    }

    @Test
    func acceptedEntryDoesNotClearAByteDistinctDraft() async throws {
        let submittedText = "caf\u{00E9}"
        let newerText = "cafe\u{0301}"
        let fixture = try DraftFixture(text: submittedText)
        let gate = EntryCreateGate()
        let store = makeStore(fixture: fixture) { _, _ in
            await gate.wait()
            return fixture.acceptedEntry
        }

        await store.send(.draftChanged(submittedText)) {
            $0.draft.text = submittedText
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.send(.draftChanged(newerText)) {
            $0.draft.hasChangedSinceSubmission = true
            $0.draft.text = newerText
        }
        await gate.open()
        await store.receive(\.entryResponse.success) {
            $0.draft.hasChangedSinceSubmission = false
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
    }

    @Test
    func failedSavePreservesDraftAndSurfacesError() async throws {
        let fixture = try DraftFixture()
        let store = makeStore(fixture: fixture) { _, _ in
            throw TestFailure.saveFailed
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.failure) {
            $0.saveState = .failed(.requestFailed)
        }
    }

    @Test
    func deletingEntryRemovesItFromTheList() async throws {
        let fixture = try DraftFixture()
        var initialState = EntriesFeature.State()
        initialState.entries = [fixture.acceptedEntry]
        let store = TestStore(initialState: initialState) {
            EntriesFeature()
        } withDependencies: {
            $0[EntryClient.self].delete = { entryID, bearerToken in
                expectNoDifference(entryID, fixture.acceptedEntry.id)
                expectNoDifference(bearerToken, fixture.token)
            }
            $0[TokenStorageClient.self].load = { fixture.token }
        }

        await store.send(.deleteButtonTapped(fixture.acceptedEntry.id)) {
            $0.deletingEntryID = fixture.acceptedEntry.id
        }
        await store.receive(\.deleteResponse.success) {
            $0.deletingEntryID = nil
            $0.entries = []
        }
    }

    @Test
    func deletedEntryDoesNotReturnWhenEarlierLoadCompletes() async throws {
        let fixture = try DraftFixture()
        var initialState = EntriesFeature.State()
        initialState.entries = [fixture.acceptedEntry]
        initialState.loadState = .loading
        let store = TestStore(initialState: initialState) {
            EntriesFeature()
        } withDependencies: {
            $0[EntryClient.self].delete = { _, _ in }
            $0[TokenStorageClient.self].load = { fixture.token }
        }

        await store.send(.deleteButtonTapped(fixture.acceptedEntry.id)) {
            $0.deletingEntryID = fixture.acceptedEntry.id
        }
        await store.receive(\.deleteResponse.success) {
            $0.deletingEntryID = nil
            $0.entries = []
            $0.entryIDsDeletedWhileLoading = [fixture.acceptedEntry.id]
        }
        await store.send(.entriesResponse(.success([fixture.acceptedEntry]))) {
            $0.entryIDsDeletedWhileLoading = []
            $0.loadState = .loaded
        }
    }

    @Test
    func failedDeleteLeavesEntryAndSurfacesError() async throws {
        let fixture = try DraftFixture()
        var initialState = EntriesFeature.State()
        initialState.entries = [fixture.acceptedEntry]
        let store = TestStore(initialState: initialState) {
            EntriesFeature()
        } withDependencies: {
            $0[EntryClient.self].delete = { _, _ in
                throw TestFailure.deleteFailed
            }
            $0[TokenStorageClient.self].load = { fixture.token }
        }

        await store.send(.deleteButtonTapped(fixture.acceptedEntry.id)) {
            $0.deletingEntryID = fixture.acceptedEntry.id
        }
        await store.receive(\.deleteResponse.failure) {
            $0.deleteError = .requestFailed
            $0.deletingEntryID = nil
        }
    }

    @Test
    func retryAfterFailureReusesEntryIdentifier() async throws {
        let fixture = try DraftFixture(id: "00000000-0000-0000-0000-000000000000")
        let creates = FailOnceEntryCreator()
        let store = makeStore(fixture: fixture, uuid: .incrementing) { submission, _ in
            try await creates.create(submission)
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.failure) {
            $0.saveState = .failed(.requestFailed)
        }

        await store.send(.entriesResponse(.success([fixture.acceptedEntry]))) {
            $0.entries = [fixture.acceptedEntry]
            $0.loadState = .loaded
        }

        await store.send(.sendButtonTapped) {
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.success) {
            $0.draft.text = ""
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
        let attempts = await creates.recordedAttempts()
        expectNoDifference(attempts, [fixture.submission, fixture.submission])
    }

    @Test
    func retryAfterFailureWhenDraftReturnsToSubmittedTextClearsDraftAndReusesIdentifier() async throws {
        let fixture = try DraftFixture(id: "00000000-0000-0000-0000-000000000000")
        let creates = FailOnceEntryCreator()
        let gate = EntryCreateGate()
        let store = makeStore(fixture: fixture, uuid: .incrementing) { submission, _ in
            await gate.wait()
            return try await creates.create(submission)
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.send(.draftChanged("lentil soup")) {
            $0.draft.hasChangedSinceSubmission = true
            $0.draft.text = "lentil soup"
        }
        await gate.open()
        await store.receive(\.entryResponse.failure) {
            $0.saveState = .failed(.requestFailed)
        }
        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
            $0.saveState = .idle
        }

        await store.send(.sendButtonTapped) {
            $0.draft.hasChangedSinceSubmission = false
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.success) {
            $0.draft.text = ""
            $0.draft.submission = nil
            $0.entries = [fixture.acceptedEntry]
            $0.saveState = .idle
        }
        let attempts = await creates.recordedAttempts()
        expectNoDifference(attempts, [fixture.submission, fixture.submission])
    }

    @Test
    func clearingDraftAfterFailureEndsItsRetryLifecycle() async throws {
        let fixture = try DraftFixture(id: "00000000-0000-0000-0000-000000000000")
        let creates = FailOnceEntryCreator()
        let gate = EntryCreateGate()
        let store = makeStore(fixture: fixture, uuid: .incrementing) { submission, _ in
            await gate.wait()
            return try await creates.create(submission)
        }

        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }
        await store.send(.sendButtonTapped) {
            $0.draft.submission = fixture.submission
            $0.saveState = .saving
        }
        await store.send(.draftChanged("lentil soup")) {
            $0.draft.hasChangedSinceSubmission = true
            $0.draft.text = "lentil soup"
        }
        await gate.open()
        await store.receive(\.entryResponse.failure) {
            $0.saveState = .failed(.requestFailed)
        }
        await store.send(.draftChanged("")) {
            $0.draft.hasChangedSinceSubmission = false
            $0.draft.submission = nil
            $0.draft.text = ""
            $0.saveState = .idle
        }
        await store.send(.draftChanged(fixture.submission.text)) {
            $0.draft.text = fixture.submission.text
        }

        let newSubmission = DraftSubmission(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            text: fixture.submission.text,
            eatenAt: fixture.submission.eatenAt
        )
        await store.send(.sendButtonTapped) {
            $0.draft.submission = newSubmission
            $0.saveState = .saving
        }
        await store.receive(\.entryResponse.success) {
            $0.draft.text = ""
            $0.draft.submission = nil
            $0.entries = [
                Entry(
                    id: newSubmission.id,
                    text: newSubmission.text,
                    eatenAt: newSubmission.eatenAt
                )
            ]
            $0.saveState = .idle
        }
        let attempts = await creates.recordedAttempts()
        expectNoDifference(attempts, [fixture.submission, newSubmission])
    }

    @Test
    func whitespaceOnlyDraftCannotBeSent() async {
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        }

        await store.send(.draftChanged(" \n\t")) {
            $0.draft.text = " \n\t"
        }
        await store.send(.sendButtonTapped)
    }

    @Test
    func zeroWidthNoBreakSpaceDraftCannotBeSent() async {
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        }

        await store.send(.draftChanged("\u{FEFF}")) {
            $0.draft.text = "\u{FEFF}"
        }
        await store.send(.sendButtonTapped)
    }

    @Test
    func emptyDraftCannotBeSent() async {
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        }

        await store.send(.sendButtonTapped)
    }

    @Test
    func loadingPopulatesEntriesForTheCurrentDayWindow() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        let expectedDayWindow = DayWindow(
            from: Date(timeIntervalSince1970: 1_786_140_000),
            to: Date(timeIntervalSince1970: 1_786_226_400)
        )
        let entries = [
            Entry(
                id: UUID(uuidString: "8E1ADDFC-9E9A-4BAF-9A1F-9A7922E3421D")!,
                text: "two eggs, toast, black coffee",
                eatenAt: Date(timeIntervalSince1970: 1_786_173_300)
            ),
            Entry(
                id: UUID(uuidString: "E6224F23-F32A-468D-878C-EF2FE665CB6B")!,
                text: "lentil soup",
                eatenAt: Date(timeIntervalSince1970: 1_786_193_100)
            ),
        ]
        let token = try #require(BearerToken("test-token"))
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        } withDependencies: {
            $0.calendar = calendar
            $0.date.now = Date(timeIntervalSince1970: 1_786_185_000)
            $0[EntryClient.self].list = { dayWindow, bearerToken in
                expectNoDifference(dayWindow, expectedDayWindow)
                expectNoDifference(bearerToken, token)
                return entries
            }
            $0[TokenStorageClient.self].load = { token }
        }

        await store.send(.task) {
            $0.loadState = .loading
        }
        await store.receive(\.entriesResponse.success) {
            $0.entries = entries
            $0.loadState = .loaded
        }
    }

    @Test
    func loadFailureProducesAnErrorStateDistinctFromEmpty() async throws {
        let token = try #require(BearerToken("test-token"))
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.date.now = Date(timeIntervalSince1970: 1_786_185_000)
            $0[EntryClient.self].list = { _, _ in
                throw TestFailure.loadFailed
            }
            $0[TokenStorageClient.self].load = { token }
        }

        await store.send(.task) {
            $0.loadState = .loading
        }
        await store.receive(\.entriesResponse.failure) {
            $0.loadState = .failed("Couldn’t load your Entries. Try again.")
        }
    }

    @Test
    func becomingActiveReloadsEntries() async throws {
        let breakfast = Entry(
            id: UUID(uuidString: "8E1ADDFC-9E9A-4BAF-9A1F-9A7922E3421D")!,
            text: "two eggs, toast, black coffee",
            eatenAt: Date(timeIntervalSince1970: 1_786_173_300)
        )
        let lunch = Entry(
            id: UUID(uuidString: "E6224F23-F32A-468D-878C-EF2FE665CB6B")!,
            text: "lentil soup",
            eatenAt: Date(timeIntervalSince1970: 1_786_193_100)
        )
        let responses = EntryResponses([[breakfast], [breakfast, lunch]])
        let token = try #require(BearerToken("test-token"))
        let store = TestStore(initialState: EntriesFeature.State()) {
            EntriesFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.date.now = Date(timeIntervalSince1970: 1_786_185_000)
            $0[EntryClient.self].list = { _, _ in
                await responses.next()
            }
            $0[TokenStorageClient.self].load = { token }
        }

        await store.send(.task) {
            $0.loadState = .loading
        }
        await store.receive(\.entriesResponse.success) {
            $0.entries = [breakfast]
            $0.loadState = .loaded
        }

        await store.send(.appDidBecomeActive) {
            $0.loadState = .loading
        }
        await store.receive(\.entriesResponse.success) {
            $0.entries = [breakfast, lunch]
            $0.loadState = .loaded
        }
    }
}
