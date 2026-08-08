import ComposableArchitecture
import SwiftUI

struct EntriesView: View {
    @Environment(\.scenePhase) private var scenePhase

    let store: StoreOf<EntriesFeature>

    var body: some View {
        NavigationStack {
            List {
                content
            }
            .navigationTitle("Food Guide")
            .refreshable {
                await store.send(.refreshRequested).finish()
            }
        }
        .onChange(of: scenePhase) { _, scenePhase in
            guard scenePhase == .active else { return }
            store.send(.appDidBecomeActive)
        }
        .task {
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loadState == .loading, store.entries.isEmpty {
            HStack {
                Spacer()
                ProgressView("Loading Entries…")
                Spacer()
            }
            .listRowSeparator(.hidden)
        } else if store.entries.isEmpty {
            if case .failed(let errorMessage) = store.loadState {
                ContentUnavailableView(
                    "Couldn’t Load Entries",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "fork.knife",
                    description: Text("Entries you record will appear here.")
                )
            }
        } else {
            if case .failed(let errorMessage) = store.loadState {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            ForEach(store.entries) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(entry.eatenAt, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(entry.text)
                }
            }
        }
    }
}
