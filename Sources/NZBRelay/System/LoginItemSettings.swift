import Observation
import ServiceManagement

/// macOS owns the login-item state. Registration changes only after a user action.
@MainActor @Observable
final class LoginItemSettings {
    private(set) var status = SMAppService.mainApp.status
    private(set) var changing = false
    @ObservationIgnored var onError: ((any Error) -> Void)?

    var requested: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        guard !changing else { return }
        refresh()
        guard enabled != requested else { return }
        changing = true
        defer { changing = false; refresh() }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { onError?(error) }
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
