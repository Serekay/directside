import Foundation

enum LocalConnectionStatus:String {
    case checking, missingVPN, noWiFi, unreachable, connected
    static func resolve(installed:Bool,reachable:Bool,wifi:Bool?)->Self {
        if reachable {return .connected}
        if !installed {return .missingVPN}
        guard let wifi else {return .checking}
        return wifi ? .unreachable:.noWiFi
    }
    var title:String {
        switch self {
        case .checking:return "Verbindung prüfen …"
        case .missingVPN:return "Nicht installiert"
        case .noWiFi:return "WLAN nicht verfügbar"
        case .unreachable:return "Nicht erreichbar"
        case .connected:return "Verbunden"
        }
    }
}

struct RenewalReminderApp:Equatable {
    var id:String
    var name:String
    var expiresAt:Date
}
struct RenewalReminder:Identifiable,Equatable {
    var app:RenewalReminderApp
    var days:Int
    var date:Date
    var id:String {"directside.renewal."+app.id+"."+String(days)}
}
enum RenewalReminderPlan {
    static func make(apps:[RenewalReminderApp],now:Date,limit:Int=60)->[RenewalReminder] {
        let unique=Dictionary(apps.map{($0.id,$0)},uniquingKeysWith:{_,new in new})
        var reminders:[RenewalReminder]=[]
        for app in unique.values {
            for days in [2,1] {
                let date=app.expiresAt.addingTimeInterval(-Double(days)*86400)
                if date>now {reminders.append(RenewalReminder(app:app,days:days,date:date))}
            }
        }
        reminders.sort { $0.date == $1.date ? $0.id<$1.id:$0.date<$1.date }
        return Array(reminders.prefix(max(0,limit)))
    }
}

struct SourceVersionNotice:Codable,Identifiable,Equatable {
    var sourceID:String
    var bundleID:String
    var version:String
    var buildVersion:String?
    var id:String {String(sourceID.utf8.count)+":"+sourceID+bundleID}
}
enum SourceVersionChanges {
    static func acknowledging(installed:ManagedApp,pending:[SourceVersionNotice])->[SourceVersionNotice] {
        pending.filter {notice in
            guard notice.bundleID==installed.id,installed.sourceID==nil || notice.sourceID==installed.sourceID else {return true}
            guard let version=installed.version,!version.isEmpty,version != "?" else {return true}
            return CatalogUpdates.isNewer(version:notice.version,buildVersion:notice.buildVersion,than:installed)
        }
    }
    static func updating(previous:SourceCatalog,current:SourceCatalog,pending:[SourceVersionNotice])->[SourceVersionNotice] {
        let old=Dictionary(grouping:previous.apps,by:{$0.id})
        var result=pending.filter{$0.sourceID != previous.id}
        for app in current.apps {
            guard let latest=app.latest else {continue}
            let saved=pending.first{$0.sourceID==previous.id && $0.bundleID==app.id}
            let changed:Bool
            if let candidates=old[app.id],candidates.count==1,let before=candidates.first?.latest {
                changed=CatalogUpdates.compare(latest,before) == .orderedDescending
            }else {changed=false}
            let stillPending=saved.map{CatalogUpdates.compare(latest,CatalogVersion(version:$0.version,downloadURL:latest.downloadURL,buildVersion:$0.buildVersion)) != .orderedAscending} ?? false
            if changed || stillPending {result.append(SourceVersionNotice(sourceID:current.id,bundleID:app.id,version:latest.version,buildVersion:latest.buildVersion))}
        }
        return result
    }
}
