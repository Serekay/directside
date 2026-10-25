import SwiftUI

struct AppIDsView:View {
    @EnvironmentObject var engine:Engine
    var body:some View {
        List {
            Section {
                HStack {
                    Label(L("App-Kennungen"),systemImage:"app.badge.checkmark").font(.headline)
                    Spacer()
                    if let limit=engine.appIDsLimit,let available=engine.appIDsAvailable {
                        Text("\(max(0,limit-available)) / \(limit)").font(.headline.monospacedDigit()).foregroundStyle(available==0 ? Color.red:Style.accent)
                    }
                }
                if let free=engine.appIDsAvailable {Text(L("\(free) Kennungen frei")).font(.subheadline).foregroundStyle(.secondary)}
                Text(L("Hier siehst du die bei Apple registrierten Kennungen. Auch App-Erweiterungen zählen. Updates derselben App verwenden ihre vorhandene Kennung wieder.")).font(.subheadline).foregroundStyle(.secondary)
            }
            if !engine.loggedIn {
                Section {Label(L("Zum Nachsehen mit deinem Apple Account anmelden."),systemImage:"person.crop.circle")}
            } else {
                Section {
                    Button {engine.loadAppIDs()}label:{Label(L("Aktualisieren"),systemImage:"arrow.clockwise")}.disabled(engine.loadingAppIDs || engine.busy)
                    if engine.loadingAppIDs {ProgressView(L("App-Kennungen laden …"))}
                    if let error=engine.appIDsError {Text(L(error)).foregroundStyle(.orange)}
                }
                Section(L("Bei Apple registriert")) {
                    ForEach(engine.appIDs) {app in
                        VStack(alignment:.leading,spacing:6) {
                            Label(L(app.displayName),systemImage:app.parent_name == nil ? "app":"puzzlepiece.extension").font(.subheadline.bold())
                            if let parent=app.parent_name {Text(L("Erweiterung für")+" "+parent).font(.caption).foregroundStyle(.secondary)}
                            if let date=app.expiration {Text(L("Läuft ab am")+" "+date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                        }.padding(.vertical,4)
                    }
                    if engine.appIDs.isEmpty,!engine.loadingAppIDs,engine.appIDsError==nil {Text(L("Keine registrierten Kennungen.")).foregroundStyle(.secondary)}
                }
            }
            Section {Text(L("Diese Liste zeigt keine installierten Apps. Deren Plätze findest du unter Meine Apps. Gast-Apps in LiveContainer benötigen keine zusätzlichen Kennungen.")).font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle(L("App-Kennungen")).task{engine.loadAppIDs()}
        .onChange(of:engine.loggedIn){_,value in if value {engine.loadAppIDs()}}
    }
}
