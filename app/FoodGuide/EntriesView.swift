import ComposableArchitecture
import SwiftUI

struct EntriesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isDraftFocused: Bool

    @Bindable var store: StoreOf<EntriesFeature>

    var body: some View {
        NavigationStack {
            List {
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composeBar
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
            isDraftFocused = true
            await store.send(.task).finish()
        }
    }

    private var composeBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .failed(let error) = store.saveState {
                Label(error.description, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "What did you eat?",
                    text: $store.draft.text.sending(\.draftChanged),
                    axis: .vertical
                )
                .focused($isDraftFocused)
                .lineLimit(1...4)
                .onSubmit {
                    store.send(.sendButtonTapped)
                }
                .submitLabel(.send)
                .textFieldStyle(.roundedBorder)

                Button {
                    store.send(.sendButtonTapped)
                } label: {
                    if store.saveState == .saving {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSend)
            }
        }
        .padding()
        .background(.bar)
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
