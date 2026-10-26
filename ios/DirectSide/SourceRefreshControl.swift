import SwiftUI
import UIKit

/// A real refresh control for both short ScrollViews and Lists. SwiftUI's
/// refresh environment alone does not install a control in every ScrollView.
struct SourceRefreshControl:UIViewRepresentable {
    let refreshing:Bool
    let action:() async->Void

    final class Anchor:UIView {
        var attach:(()->Void)?
        override func didMoveToWindow() {super.didMoveToWindow();attach?()}
        override func didMoveToSuperview() {super.didMoveToSuperview();attach?()}
    }
    @MainActor final class Coordinator:NSObject {
        var action:() async->Void
        let control=UIRefreshControl()
        weak var scroll:UIScrollView?
        var task:Task<Void,Never>?
        init(action:@escaping () async->Void) {
            self.action=action;super.init()
            control.addTarget(self,action:#selector(refresh),for:.valueChanged)
        }
        func attach(to anchor:UIView) {
            var parent=anchor.superview
            while let view=parent {
                if let scroll=view as? UIScrollView {
                    self.scroll=scroll;scroll.alwaysBounceVertical=true
                    if scroll.refreshControl !== control {scroll.refreshControl=control}
                    return
                }
                parent=view.superview
            }
        }
        @objc func refresh() {
            guard task==nil else {return}
            task=Task {@MainActor in
                await action()
                control.endRefreshing();task=nil
            }
        }
        func update(refreshing:Bool) {
            if refreshing && !control.isRefreshing {control.beginRefreshing()}
            else if !refreshing && task==nil {control.endRefreshing()}
        }
    }
    func makeCoordinator()->Coordinator {Coordinator(action:action)}
    func makeUIView(context:Context)->Anchor {
        let anchor=Anchor();anchor.isUserInteractionEnabled=false
        anchor.attach={[weak anchor,weak coordinator=context.coordinator] in
            DispatchQueue.main.async {if let anchor {coordinator?.attach(to:anchor)}}
        }
        return anchor
    }
    func updateUIView(_ anchor:Anchor,context:Context) {
        context.coordinator.action=action
        DispatchQueue.main.async {
            context.coordinator.attach(to:anchor)
            context.coordinator.update(refreshing:refreshing)
        }
    }
    static func dismantleUIView(_ anchor:Anchor,coordinator:Coordinator) {
        if coordinator.scroll?.refreshControl === coordinator.control {coordinator.scroll?.refreshControl=nil}
        anchor.attach=nil
    }
}
