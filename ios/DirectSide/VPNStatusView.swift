import SwiftUI

struct VPNStatusView:View {
    @ObservedObject var connection:Connection
    var body:some View {
        HStack(spacing:8) {
            Circle().fill(connection.vpnReachable ? Color.green:connection.vpnInstalled ? Color.orange:Color.red).frame(width:7,height:7)
            Text(L(connection.vpnReachable ? "LocalDevVPN verbunden":connection.vpnInstalled ? "LocalDevVPN verbinden":"LocalDevVPN fehlt")).font(.caption.weight(.semibold))
            Spacer()
            if !connection.vpnInstalled {
                Link(L("Installieren"),destination:URL(string:"https://apps.apple.com/app/id6755608044")!).font(.caption.bold())
            } else if !connection.vpnReachable {
                Button(L("Verbinden")){connection.openVPN()}.font(.caption.bold()).disabled(!connection.vpnInstalled)
            }
        }.padding(.horizontal,18).padding(.vertical,9).background(.ultraThinMaterial)
    }
}
