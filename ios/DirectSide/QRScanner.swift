import SwiftUI
import VisionKit

struct QRScanner: UIViewControllerRepresentable {
    var onCode: (String)->Void
    func makeCoordinator() -> Coordinator { Coordinator(onCode:onCode) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller=DataScannerViewController(recognizedDataTypes:[.barcode(symbologies:[.qr])],qualityLevel:.balanced,recognizesMultipleItems:false,isHighFrameRateTrackingEnabled:false,isHighlightingEnabled:true)
        controller.delegate=context.coordinator
        context.coordinator.controller=controller
        do { try controller.startScanning() } catch { context.coordinator.failure=error.localizedDescription }
        return controller
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController,context:Context) {}
    static func dismantleUIViewController(_ uiViewController:DataScannerViewController,coordinator:Coordinator) { uiViewController.stopScanning() }
    final class Coordinator: NSObject,DataScannerViewControllerDelegate {
        let onCode:(String)->Void
        weak var controller:DataScannerViewController?
        var done=false
        var failure:String?
        init(onCode:@escaping(String)->Void) { self.onCode=onCode }
        func dataScanner(_ dataScanner:DataScannerViewController,didAdd addedItems:[RecognizedItem],allItems:[RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let barcode)=item, let payload=barcode.payloadStringValue {
                    done=true; dataScanner.stopScanning(); onCode(payload); return
                }
            }
        }
    }
}
