import ComposableArchitecture
import SwiftUI

@main
struct FoodGuideApp: App {
    private let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    init() {
        _ = AppConfiguration.backendBaseURL
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
