import CoreData
import CoreDataSupport

final class ExtendedFetchedResultsControllerObservation {
    private let nc: NotificationCenter
    private static let lock = Lock()
    private static var delegates: [ObjectIdentifier: ExtendedFetchedResultsControllerNotifyingDelegate] = [:]

    private let handler: (Event<NSFetchRequestResult>) -> Void
    
    public enum Event<EntityType: NSFetchRequestResult> {
        case willChangeContent
        case updateWithChange(_ change: WrappedNSFetchedResultsController<EntityType>.ChangeType)
        case didChangeContent
        
        func map<U: NSFetchRequestResult>(_ transform: (EntityType) -> U) -> Event<U> {
            switch self {
            case .willChangeContent: return .willChangeContent
            case .updateWithChange(let change): return .updateWithChange(change.map(transform))
            case .didChangeContent: return .didChangeContent
            }
        }
    }
    
    public init<EntityType>(_ frc: ExtendedFetchedResultsController<EntityType>, nc: NotificationCenter = .default, handler: @escaping (Event<EntityType>) -> Void) where EntityType: NSFetchRequestResult {
        self.handler = { handler($0.map { $0 as! EntityType }) }
        self.nc = nc
        
        Self.lock.withLock {
            if Self.delegates[ObjectIdentifier(frc)] == nil {
                Self.delegates[ObjectIdentifier(frc)] = ExtendedFetchedResultsControllerNotifyingDelegate(for: frc, nc: nc)
            }
            frc.delegate = Self.delegates[ObjectIdentifier(frc)]
        }
        
        nc.addObserver(forName: .willChangeContent, object: frc, queue: nil) { note in
            handler(.willChangeContent)
        }
        nc.addObserver(forName: .updateWithChange, object: frc, queue: nil) { note in
            handler(.updateWithChange(note.userInfo![ChangeKey] as! WrappedNSFetchedResultsController<EntityType>.ChangeType))
        }
        nc.addObserver(forName: .didChangeContent, object: frc, queue: nil) { note in
            handler(.didChangeContent)
        }
    }
    
    deinit {
        nc.removeObserver(self)
        Self.lock.withLock { Self.delegates[ObjectIdentifier(self)] = nil }
    }
}

private final class ExtendedFetchedResultsControllerNotifyingDelegate: NSObject, FetchedResultsControllerDelegate {
    private let nc: NotificationCenter
    private weak var frc: AnyObject?
    
    init<EntityType>(for frc: ExtendedFetchedResultsController<EntityType>, nc: NotificationCenter) {
        self.nc = nc
        self.frc = frc
        super.init()
        frc.delegate = self
    }
    func willChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        guard controller === frc else { return }
        nc.post(name: .willChangeContent, object: controller)
    }
    
    func updateWithChange<T>(_ controller: WrappedNSFetchedResultsController<T>, change: WrappedNSFetchedResultsController<T>.ChangeType) where T: NSFetchRequestResult {
        guard controller === frc else { return }
        nc.post(name: .updateWithChange, object: controller, userInfo: [ChangeKey: change])
    }
    
    func didChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        guard controller === frc else { return }
        nc.post(name: .didChangeContent, object: controller)
    }
}

extension WrappedNSFetchedResultsController.ChangeType {
    func map<U: NSFetchRequestResult>(_ transform: (EntityType) -> U) -> WrappedNSFetchedResultsController<U>.ChangeType {
        switch self {
        case let .insert(object: object, at: indexPath):
            return .insert(object: transform(object), at: indexPath)
        case let .update(object: object, at: indexPath, progressiveChangeIndexPath: progressiveChangeIndexPath):
            return .update(object: transform(object), at: indexPath, progressiveChangeIndexPath: progressiveChangeIndexPath)
        case let .move(object: object, from: fromIndexPath, to: toIndexPath, progressiveChangeIndexPath: progressiveChangeIndexPath):
            return .move(object: transform(object), from: fromIndexPath, to: toIndexPath, progressiveChangeIndexPath: progressiveChangeIndexPath)
        case let .delete(object: object, at: indexPath, progressiveChangeIndexPath: progressiveChangeIndexPath):
            return .delete(object: transform(object), at: indexPath, progressiveChangeIndexPath: progressiveChangeIndexPath)
        }
    }
}

extension Notification.Name {
    fileprivate static let willChangeContent: Notification.Name = .init("willChangeContent")
    fileprivate static let updateWithChange: Notification.Name = .init("updateWithChange")
    fileprivate static let didChangeContent: Notification.Name = .init("didChangeContent")
}

private let ChangeKey: String = "change"
