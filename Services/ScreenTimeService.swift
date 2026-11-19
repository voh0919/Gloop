// Real Screen Time integration (not wired into the UI yet).
//
// The prototype runs on mock data. To block apps for real you need:
//  1. The Family Controls capability. Development works on a real iPhone
//     (not the Simulator); App Store release needs Apple's approval of the
//     entitlement.
//  2. A full Xcode project (instead of this App Playground) so you can add the
//     app extensions Screen Time requires:
//       - Shield Configuration: draws the block screen in other apps
//       - Shield Action: handles "Ask for time" on that block screen
//       - Device Activity Monitor: fires when daily limits are reached
//  3. A small server + push notifications to deliver requests and answers
//     between friends' phones.

#if os(iOS) && canImport(FamilyControls)
import FamilyControls
import ManagedSettings

@MainActor
final class ScreenTimeService {
    static let shared = ScreenTimeService()

    private let store = ManagedSettingsStore()

    /// The apps the user picked with `FamilyActivityPicker`.
    var selection = FamilyActivitySelection()

    /// Buddy mode asks for `.individual`; Family mode asks for `.child`,
    /// which needs the parent's approval through Family Sharing.
    func requestAuthorization(mode: LinkMode) async throws {
        try await AuthorizationCenter.shared.requestAuthorization(
            for: mode == .family ? .child : .individual)
    }

    /// Turns the block screens on for every selected app.
    func applyShields() {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    /// Lifts the block screens after a keyholder says yes. The real version
    /// should schedule re-blocking with a DeviceActivity schedule so it still
    /// happens if the app isn't running.
    func liftShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
#endif
