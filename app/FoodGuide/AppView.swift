// © 2026 Andrei Chenchik. All rights reserved.
// Unauthorized using, copying, distribution, or modification prohibited.

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.screen {
            case .launching:
                ProgressView()

            case .main:
                ContentView()

            case .onboarding:
                onboarding
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }

    private var onboarding: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Unlock Food Guide")
                    .font(.title.bold())
                Text("Enter the bearer token once. It will be kept securely in this device’s Keychain.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SecureField(
                "Bearer token",
                text: $store.token.sending(\.tokenChanged)
            )
            .autocorrectionDisabled()
            .textContentType(.password)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button("Continue") {
                store.send(.continueButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canContinue)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
