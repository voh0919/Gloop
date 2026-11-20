import SwiftUI

@main
struct GloopApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                .fontDesign(.rounded) // softer, friendlier type everywhere
        }
    }
}

/// Logged in: the app. Logged out: welcome, sign up or log in.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if model.isLoggedIn {
                MainView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                AuthFlow()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(Motion.smooth, value: model.isLoggedIn)
        // With the server connected, check the saved session is still good.
        .task { await model.refreshAccount() }
    }
}
