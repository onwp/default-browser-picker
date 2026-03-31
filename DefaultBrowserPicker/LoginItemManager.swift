import ServiceManagement

final class LoginItemManager {
    private let service = SMAppService.mainApp

    /// Whether the app is currently registered as a login item.
    var isEnabled: Bool {
        service.status == .enabled
    }

    /// Toggles the login item registration.
    func toggle() {
        do {
            if isEnabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("LoginItemManager: Failed to toggle login item: \(error.localizedDescription)")
        }
    }
}
