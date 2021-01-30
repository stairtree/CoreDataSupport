import CoreData
import CoreDataSupport

final class ExtendedFetchedResultsControllerObserver<EntityType: NSFetchRequestResult>: NSObject, FetchedResultsControllerDelegate {
    private weak var fetchedResultsController: ExtendedFetchedResultsController<EntityType>!
    private let handler: (Event) -> Void
    
    public enum Event {
        case willChangeContent
        case updateWithChange(_ change: WrappedNSFetchedResultsController<EntityType>.ChangeType)
        case didChangeContent
    }
    
    public init(_ frc: ExtendedFetchedResultsController<EntityType>, handler: @escaping (Event) -> Void) {
        self.fetchedResultsController = frc
        self.handler = handler
        super.init()
        frc.delegate = self
    }
    
    func willChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        handler(.willChangeContent)
    }
    
    func updateWithChange<T>(_ controller: WrappedNSFetchedResultsController<T>, change: WrappedNSFetchedResultsController<T>.ChangeType) where T: NSFetchRequestResult {
        handler(.updateWithChange(change as! WrappedNSFetchedResultsController<EntityType>.ChangeType))
    }
    
    func didChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        handler(.didChangeContent)
    }
}
