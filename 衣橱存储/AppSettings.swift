import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AppSettings {
    static func open() {
        #if canImport(UIKit)
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
        #endif
    }
}
