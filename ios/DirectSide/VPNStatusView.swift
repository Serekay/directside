import SwiftUI

struct VPNStatusView:View {
    @ObservedObject var connection:Connection
    var showsSetupGuide=false
    private var tone:Color {connection.vpnReachable ? .green:connection.vpnInstalled ? .orange:.red}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Label("LocalDevVPN",systemImage:"network").font(.subheadline.bold())
                Spacer()
                Label(L(connection.vpnReachable ? "Verbunden":connection.vpnInstalled ? "Nicht verbunden":"Nicht installiert"),systemImage:connection.vpnReachable ? "checkmark.circle.fill":"exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(tone)
                    .padding(.horizontal,11).padding(.vertical,7).background(tone.opacity(0.12),in:Capsule())
            }
            if showsSetupGuide && !connection.vpnReachable {
                VStack(alignment:.leading,spacing:10) {
                    if !connection.vpnInstalled {
                        Text(L("1. LocalDevVPN aus dem App Store installieren und öffnen."))
                    } else {
                        Text(L("1. LocalDevVPN öffnen."))
                    }
                    Text(L("2. Der Anleitung in LocalDevVPN folgen und die VPN-Einrichtung erlauben."))
                    Text(L("3. Dort verbinden und anschließend zu DirectSide zurückkehren."))
                }.font(.subheadline).fixedSize(horizontal:false,vertical:true)
            }
            if !connection.vpnInstalled {
                Link(L("LocalDevVPN installieren"),destination:URL(string:"https://apps.apple.com/app/id6755608044")!).font(.subheadline.bold())
            } else if !connection.vpnReachable {
                Button(L(showsSetupGuide ? "LocalDevVPN öffnen":"Verbinden")){connection.openVPN()}.font(.subheadline.bold())
            }
        }.padding(18).background(Style.surface,in:RoundedRectangle(cornerRadius:18))
    }
}
