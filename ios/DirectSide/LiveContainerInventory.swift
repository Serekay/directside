import Foundation

struct LiveContainerGuest:Codable,Identifiable,Equatable {
    var hostID:String
    var bundleID:String
    var name:String
    var version:String?
    var buildVersion:String?
    var readAt:Date?
    var id:String {[hostID,bundleID,version ?? "",buildVersion ?? ""].map{String($0.utf8.count)+":"+$0}.joined()}
    var comparisonRecord:ManagedApp {ManagedApp(id:bundleID,name:name,cachedIPA:"",installedAt:readAt ?? .distantPast,version:version,buildVersion:buildVersion)}
}
struct LiveContainerHostInventory:Decodable {
    var hostID:String
    var state:String
    var apps:[LiveContainerGuest]
}
struct LiveContainerGuestUpdate:Identifiable {
    var app:CatalogApp
    var source:SourceCatalog
    var id:String {source.id+"|"+app.id}
}
enum LiveContainerInventory {
    static func reconcile(previous:[LiveContainerGuest],hosts:[LiveContainerHostInventory],now:Date)->[LiveContainerGuest] {
        var result:[LiveContainerGuest]=[]
        for host in hosts {
            var saved:[LiveContainerGuest]=host.state=="ready" ? []:previous.filter{$0.hostID==host.hostID}
            if ["ready","partial"].contains(host.state) {
                for var app in host.apps where app.hostID==host.hostID {
                    app.readAt=now;saved.removeAll{$0.id==app.id};saved.append(app)
                }
            }
            result.append(contentsOf:saved)
        }
        return result.sorted{$0.id<$1.id}
    }
    static func candidates(for guest:LiveContainerGuest,sources:[SourceCatalog])->[LiveContainerGuestUpdate] {
        sources.compactMap {source->LiveContainerGuestUpdate? in
            guard let app=source.apps.first(where:{$0.id==guest.bundleID}),let latest=app.latest,
                  CatalogUpdates.isNewer(latest,than:guest.comparisonRecord) else {return nil}
            return LiveContainerGuestUpdate(app:app,source:source)
        }
    }
}
