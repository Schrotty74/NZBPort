import SwiftUI

struct UpdateView: View {
    @Bindable var settings: UpdateSettings
    var body: some View {
        VStack(alignment: .leading, spacing: RelayTheme.sectionSpacing) {
            Text(L("App-Updates")).font(RelayTheme.pageTitleFont)
            Toggle(L("Testversionen berücksichtigen"), isOn: $settings.includePrereleases)
            Button(L("Nach Updates suchen")) { Task { await settings.check() } }
                .disabled(settings.checking).relayPrimaryAction()
            if settings.checking { BusyRow(text: L("Suche nach Updates …")) }
            if let update = settings.available {
                Text(L("Neue Version: \(update.version)"))
                Button(L("Downloadseite öffnen")) { settings.openAvailableRelease() }
            } else if let message = settings.message { Text(L(message)) }
            Text(L("Die Prüfung fragt GitHub nur auf deinen Wunsch ab. Downloads und Installation startest du selbst."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
