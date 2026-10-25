import SwiftUI

struct OnboardingView:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    let finish:()->Void
    @AppStorage("onboardingStep") private var step=0
    @Environment(\.scenePhase) private var phase
    @State private var liveContainerInstalled=LiveContainerBridge.available
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:26) {
                    HStack(spacing:7) {
                        ForEach(0..<3) {index in Capsule().fill(index==step ? Style.accent:Color.secondary.opacity(0.2)).frame(width:index==step ? 30:8,height:6)}
                        Spacer()
                    }.accessibilityLabel(L("Einrichtung"))
                    hero
                    if step==0 {welcome}
                    else if step==1 {preparation}
                    else {liveContainer}
                }.padding(24).frame(maxWidth:560)
            }.background(Style.background)
            .safeAreaInset(edge:.bottom) {footer.padding(24).background(Style.background)}
            .toolbar {
                ToolbarItem(placement:.topBarLeading) {if step>0 {Button(L("Zurück")){withAnimation{step-=1}}}}
                ToolbarItem(placement:.topBarTrailing) {Button(L("Überspringen")){finish()}.disabled(engine.showsProgress)}
            }
            .onChange(of:phase){_,value in if value == .active {liveContainerInstalled=LiveContainerBridge.available}}
        }.tint(Style.accent)
    }
    private var hero:some View {
        VStack(alignment:.leading,spacing:15) {
            if step==0 {BrandIcon(size:82)}
            else if step==1 {Image(systemName:"checkmark.shield.fill").font(.system(size:54)).foregroundStyle(Style.accent).padding(.vertical,8)}
            else {Image("livecontainer-directside").resizable().scaledToFit().frame(width:82,height:82).clipShape(RoundedRectangle(cornerRadius:19))}
            if step==0 {
                Text(L("Willkommen bei")).font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                Text("DirectSide").font(.largeTitle.bold()).lineLimit(1).minimumScaleFactor(0.75)
            } else {Text(L(step==1 ? "Verbindung einrichten":"Mehr Platz für deine Apps")).font(.largeTitle.bold())}
        }
    }
    private var welcome:some View {
        VStack(alignment:.leading,spacing:25) {
            Label(L("Apps entdecken"),systemImage:"safari")
            Label(L("Auf dem iPhone installieren"),systemImage:"arrow.down.app")
            Label(L("Signaturen erneuern"),systemImage:"arrow.triangle.2.circlepath")
        }.font(.headline).padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Style.surface,in:RoundedRectangle(cornerRadius:20))
    }
    private var preparation:some View {
        VStack(spacing:18) {
            VPNStatusView(connection:connection)
            if !engine.pairingReady {
                NavigationLink {ConnectionSettings(connection:connection)} label:{Label(L("Dieses Gerät koppeln"),systemImage:"link").font(.headline)}
            }
        }
    }
    private var liveContainer:some View {
        VStack(alignment:.leading,spacing:20) {
            Text("LiveContainer").font(.title2.bold())
            Text(L("Mehrere Apps in einem App-Platz. Manche Apps sind damit nicht kompatibel.")).font(.title3).foregroundStyle(.secondary)
            if liveContainerInstalled {Label(L("Installiert"),systemImage:"checkmark.circle.fill").foregroundStyle(.green)}
            if !engine.canSign && !engine.preparingAccount {
                NavigationLink(L("Anmelden")){AppleAccountSettings()}
                NavigationLink(L("Eigenes Zertifikat verwenden")){ImportedSigningSettings()}
            }
            if engine.showsProgress {EngineProgress()}
        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Style.surface,in:RoundedRectangle(cornerRadius:20))
    }
    private var footer:some View {
        VStack(spacing:16) {
            if step<2 {
                Button(L(step==0 ? "Los geht’s":"Weiter")){withAnimation{step+=1}}
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth:.infinity)
                    .disabled(step==1 && (!engine.pairingReady || !connection.vpnReachable))
            } else {
                if liveContainerInstalled {Button(L("Fertig")){finish()}.buttonStyle(.borderedProminent).controlSize(.large).disabled(engine.busy)}
                else {
                    Button(L(engine.preparingAccount ? "Vorbereiten …":"LiveContainer installieren")){Task{await engine.installLiveContainer(peer:connection.peer,port:connection.port);liveContainerInstalled=LiveContainerBridge.available}}
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(engine.busy || !engine.canSign || !engine.pairingReady || !connection.vpnReachable)
                    Button(L("Ohne LiveContainer fortfahren")){finish()}.disabled(engine.showsProgress)
                }
            }
        }.frame(maxWidth:.infinity)
    }
}
