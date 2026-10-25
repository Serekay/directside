import SwiftUI
import UIKit

/// One window recognizer also covers presented sheets without consuming their controls.
struct KeyboardDismissal: UIViewRepresentable {
    func makeUIView(context: Context) -> DismissView { DismissView() }
    func updateUIView(_ view: DismissView, context: Context) {}
    static func dismantleUIView(_ view: DismissView, coordinator: ()) { view.detach() }

    final class DismissView: UIView, UIGestureRecognizerDelegate {
        private weak var attachedWindow: UIWindow?
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            attachedWindow = window
        }
        func detach() { attachedWindow?.removeGestureRecognizer(tap); attachedWindow = nil }
        @objc private func dismissKeyboard() { attachedWindow?.endEditing(true) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
