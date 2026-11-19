import SwiftUI
import HandspanCore

@main
struct HandspanApp: App {
    @State private var model = AppModel.live()
    @State private var audio = AudioInput()
    @State private var store = StoreModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(audio)
                .environment(store)
                .task {
                    store.syncToServer = { [model] jws in await model.syncSubscription(jws) }
                    await store.refreshEntitlement()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.sync() } }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.state.onboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(Motion.standard, value: model.state.onboarded)
        .tint(Palette.tint)
    }
}

/// "iPhone" or "iPad", for sentences like "The sound stays on this iPhone."
enum DeviceWord {
    @MainActor static var current: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}

/// The price in onboarding copy, before StoreKit has loaded (pricing.md, not confirmed).
/// The paywall shows StoreKit's `displayPrice` in the user's own currency.
enum PriceCopy {
    static let monthly = "$9.99"
}
