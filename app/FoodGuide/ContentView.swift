// © 2026 Andrei Chenchik. All rights reserved.
// Unauthorized using, copying, distribution, or modification prohibited.

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Food Guide")
                .font(.title.bold())
            Text("Your Entries will appear here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
