import Foundation

extension Data {
    func hexStringFromPushToken() -> String {
        self.map({ String(format: "%02.2hhx", $0) }).joined()
    }
}
