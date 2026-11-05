import Foundation
import Combine
import UserNotifications

@MainActor final class RenewalNotifications:NSObject,ObservableObject,UNUserNotificationCenterDelegate {
    static let shared=RenewalNotifications()
    @Published private(set) var enabled=UserDefaults.standard.bool(forKey:"renewalReminders")
    @Published private(set) var allowed=false
    @Published private(set) var error:String?
    @Published var showLibrary=false
    private let center=UNUserNotificationCenter.current()
    private var worker:Task<Void,Never>?
    private var generation=0
    private var apps:[RenewalReminderApp]=[]
    private var language="en"
    override init(){super.init();center.delegate=self}

    func setEnabled(_ value:Bool) async {
        if value {
            do {_ = try await center.requestAuthorization(options:[.alert,.sound])}
            catch {self.error="Mitteilungen konnten nicht eingerichtet werden.";return}
        }
        enabled=value;UserDefaults.standard.set(value,forKey:"renewalReminders")
        update(apps:apps,language:language)
    }
    func update(apps:[RenewalReminderApp],language:String) {
        self.apps=apps;self.language=language;generation+=1
        let id=generation,previous=worker
        worker=Task {
            await previous?.value
            guard self.generation==id else {return}
            await self.apply(apps:apps,language:language)
        }
    }
    private func apply(apps:[RenewalReminderApp],language:String) async {
        let settings=await center.notificationSettings()
        allowed=[.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus)
        let plan=enabled && allowed ? RenewalReminderPlan.make(apps:apps,now:Date()):[]
        let desired=Set(plan.map(\.id))
        let pending=await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:pending.filter{$0.identifier.hasPrefix("directside.renewal.") && !desired.contains($0.identifier)}.map(\.identifier))
        let current=Dictionary(apps.map{($0.id,$0.expiresAt)},uniquingKeysWith:{_,new in new})
        let delivered=await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers:delivered.filter {note in
            guard note.request.identifier.hasPrefix("directside.renewal.") else {return false}
            let info=note.request.content.userInfo
            guard enabled,let app=info["appID"] as? String,let expiry=info["expiry"] as? Double,let date=current[app] else {return true}
            return abs(date.timeIntervalSince1970-expiry)>1
        }.map{$0.request.identifier})
        error=nil
        for item in plan {
            let content=UNMutableNotificationContent()
            content.title=AppLocalization.translate("Signatur läuft bald ab",language:language)
            let text=item.days==2 ? "Die Signatur von \(item.app.name) läuft in 2 Tagen ab. Jetzt in DirectSide erneuern.":"Die Signatur von \(item.app.name) läuft in einem Tag ab. Jetzt in DirectSide erneuern."
            content.body=AppLocalization.translate(text,language:language)
            content.sound = .default
            content.userInfo=["appID":item.app.id,"expiry":item.app.expiresAt.timeIntervalSince1970]
            var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
            var parts=calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:item.date);parts.timeZone=calendar.timeZone
            let trigger=UNCalendarNotificationTrigger(dateMatching:parts,repeats:false)
            let request=UNNotificationRequest(identifier:item.id,content:content,trigger:trigger)
            do {try await center.add(request)} catch {self.error="Mitteilungen konnten nicht eingerichtet werden."}
        }
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification) async->UNNotificationPresentationOptions { [.banner,.sound] }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse) async {
        if response.notification.request.identifier.hasPrefix("directside.renewal.") {await MainActor.run{self.showLibrary=true}}
    }
}
