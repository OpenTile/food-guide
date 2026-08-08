import ComposableArchitecture
import CustomDump
import Foundation
import Testing
@testable import FoodGuide

@MainActor
struct EntriesFeatureTests {
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
        case loadFailed
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
