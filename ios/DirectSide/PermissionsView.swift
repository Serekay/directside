import SwiftUI

struct PermissionsView: View {
    let permissions: AppPermissions
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Label(L("Zugriff & Funktionen"),systemImage:"hand.raised.fill").font(.headline)
            Text(L("Diese Angaben stammen aus der Quelle. Geschützte Daten gibt iOS erst nach deiner Zustimmung frei. Du kannst den Zugriff später in den iPhone-Einstellungen ändern.")).font(.caption).foregroundStyle(.secondary)
            ForEach((permissions.privacy ?? [:]).keys.sorted(),id:\.self) { key in
                row(key,privacy:true)
            }
            ForEach(Array(Set(permissions.entitlements ?? [])).sorted(),id:\.self) { key in
                row(key,privacy:false)
            }
        }.padding(18).background(Style.surface,in:RoundedRectangle(cornerRadius:18))
    }
    private func row(_ key:String,privacy:Bool)->some View {
        let item=PermissionDescription.describe(key,privacy:privacy)
        return HStack(alignment:.top,spacing:12) {
            Image(systemName:item.icon).foregroundStyle(Style.accent).frame(width:24)
            VStack(alignment:.leading,spacing:4) {
                Text(L(item.title)).font(.subheadline.bold())
                Text(L(item.detail)).font(.caption).foregroundStyle(.secondary)
                if let reason=permissions.privacy?[key],!reason.isEmpty {
                    Text(L("Angabe des Anbieters:")+" "+reason).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

enum PermissionDescription {
    struct Item { let title:String;let detail:String;let icon:String }
    static func describe(_ key:String,privacy:Bool)->Item {
        let value=key.lowercased()
        let entries:[(String,Item)]=[
            ("camera",Item(title:"Kamera",detail:"Fotos und Videos mit der Kamera aufnehmen.",icon:"camera")),
            ("microphone",Item(title:"Mikrofon",detail:"Ton aufnehmen, zum Beispiel für Videos oder Gespräche.",icon:"mic")),
            ("photolibraryadd",Item(title:"Fotos speichern",detail:"Bilder und Videos in deiner Fotomediathek sichern.",icon:"photo.badge.plus")),
            ("photolibrary",Item(title:"Fotos & Videos",detail:"Auf von dir freigegebene Bilder und Videos zugreifen.",icon:"photo")),
            ("location",Item(title:"Standort",detail:"Deinen Standort für Funktionen der App verwenden. iOS fragt nach dem erlaubten Umfang.",icon:"location")),
            ("contacts",Item(title:"Kontakte",detail:"Auf von dir freigegebene Kontakte zugreifen.",icon:"person.crop.circle")),
            ("calendar",Item(title:"Kalender",detail:"Termine lesen oder hinzufügen, abhängig von deiner Freigabe.",icon:"calendar")),
            ("reminders",Item(title:"Erinnerungen",detail:"Erinnerungen lesen und verwalten.",icon:"checklist")),
            ("bluetooth",Item(title:"Bluetooth",detail:"Mit Bluetooth-Geräten in deiner Nähe kommunizieren.",icon:"antenna.radiowaves.left.and.right")),
            ("localnetwork",Item(title:"Lokales Netzwerk",detail:"Geräte und Dienste in deinem Netzwerk finden und verbinden.",icon:"network")),
            ("speech",Item(title:"Spracherkennung",detail:"Gesprochene Wörter in Text umwandeln.",icon:"waveform")),
            ("faceid",Item(title:"Face ID",detail:"Deine Identität mit Face ID bestätigen.",icon:"faceid")),
            ("health",Item(title:"Gesundheit",detail:"Mit deiner Zustimmung auf ausgewählte Gesundheitsdaten zugreifen.",icon:"heart")),
            ("motion",Item(title:"Bewegung & Fitness",detail:"Bewegungs- und Fitnessdaten des Geräts verwenden.",icon:"figure.walk")),
            ("tracking",Item(title:"Tracking",detail:"Um Erlaubnis bitten, Aktivitäten über Apps und Websites hinweg zuzuordnen.",icon:"hand.raised")),
            ("applemusic",Item(title:"Musikmediathek",detail:"Auf deine Musikmediathek zugreifen.",icon:"music.note")),
            ("push",Item(title:"Mitteilungen",detail:"Mitteilungen unterstützen. Die Zustellung hängt von der Signierung und deiner Freigabe ab.",icon:"bell")),
            ("aps-environment",Item(title:"Mitteilungen",detail:"Mitteilungen unterstützen. Die Zustellung hängt von der Signierung und deiner Freigabe ab.",icon:"bell")),
            ("keychain",Item(title:"Sichere Zugangsdaten",detail:"Zugangsdaten im Schlüsselbund speichern oder mit berechtigten Apps teilen.",icon:"key")),
            ("application-groups",Item(title:"Gemeinsame App-Daten",detail:"Daten mit zugehörigen Apps oder Erweiterungen teilen.",icon:"square.stack.3d.up")),
            ("associated-domains",Item(title:"Verknüpfte Websites",detail:"Links zu unterstützten Websites direkt in der App öffnen.",icon:"link")),
            ("icloud",Item(title:"iCloud",detail:"Daten über iCloud speichern oder synchronisieren, sofern die Signierung dies erlaubt.",icon:"icloud")),
            ("get-task-allow",Item(title:"Entwicklerzugriff",detail:"Die App zum Testen mit Entwicklungswerkzeugen verbinden.",icon:"hammer")),
            ("application-identifier",Item(title:"App-Identität",detail:"Die App ihrem Signierzertifikat zuordnen.",icon:"checkmark.seal")),
            ("team-identifier",Item(title:"Entwicklerteam",detail:"Das für die Signierung verantwortliche Team zuordnen.",icon:"person.2"))
        ]
        return entries.first(where:{value.contains($0.0)})?.1 ?? Item(title:privacy ? "Weiterer Datenzugriff":"Weitere App-Funktion",detail:"Die Quelle nennt eine zusätzliche Funktion dieser App.",icon:"info.circle")
    }
}
