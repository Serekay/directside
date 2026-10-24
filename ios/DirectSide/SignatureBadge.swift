import SwiftUI

struct SignatureBadge:View {
    let expiresAt:Date?
    let action:()->Void
    var body:some View {Button(action:action){SignatureLabel(expiresAt:expiresAt)}.buttonStyle(.plain).accessibilityLabel(L("Signatur erneuern"))}
}

struct SignatureLabel:View {
    let expiresAt:Date?
    var body:some View {
        TimelineView(.periodic(from:.now,by:60)) {context in
            let days=SignatureStatus.days(until:expiresAt,now:context.date)
            let tone=SignatureStatus.tone(days:days)
            let color=tone=="critical" ? Color.red:tone=="ok" ? Style.accent:Color(red:0.76,green:0.55,blue:0.04)
                Text(L(days.map{"\($0) Tage"} ?? "Prüfen")).font(.caption.bold()).monospacedDigit()
                    .padding(.horizontal,12).padding(.vertical,9)
                    .foregroundStyle(color).background(color.opacity(tone=="critical" ? 0.2:0.1),in:Capsule())
                    .overlay{Capsule().strokeBorder(color.opacity(tone=="critical" ? 0.6:0.25),lineWidth:1)}
        }
    }
}
