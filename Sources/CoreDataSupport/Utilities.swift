import Foundation

extension Sequence where Self.Element: AnyObject {
    public func containsObjectIdentical(to object: AnyObject) -> Bool {
        return contains { $0 === object }
    }
}

extension URL {
    static var temporary: URL {
        return URL(fileURLWithPath:NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    }
}
