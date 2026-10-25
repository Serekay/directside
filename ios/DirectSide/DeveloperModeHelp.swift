import SwiftUI

struct DeveloperModeHelp: View {
    var body: some View {
        List {
            Section {
                Label(L("Vor dem ersten Start"), systemImage: "hammer.fill").font(.headline)
                Text(L("Selbst signierte Entwickler-Apps benötigen ab iOS 16 den Entwicklermodus. Richte ihn nach der ersten Installation ein, bevor du DirectSide oder eine andere Entwickler-App öffnest."))
            }
            Section(L("Auf dem iPhone")) {
                Label(L("1. Einstellungen → Datenschutz & Sicherheit → Entwicklermodus einschalten."), systemImage: "gearshape")
                Label(L("2. Das iPhone neu starten und den Entwicklermodus nach dem Entsperren bestätigen."), systemImage: "arrow.clockwise")
                Label(L("3. Falls verlangt: Einstellungen → Allgemein → VPN & Geräteverwaltung öffnen und deinem Entwicklerprofil vertrauen."), systemImage: "checkmark.shield")
            } footer: {
                Text(L("Fehlt der Schalter, installiere zuerst eine Entwickler-App über die Windows-App und öffne die Einstellungen erneut. Bei Verteilungszertifikaten kann der Entwicklermodus entfallen."))
            }
        }.navigationTitle(L("Entwicklermodus"))
    }
}
