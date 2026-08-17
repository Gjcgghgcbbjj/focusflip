import Foundation
import CoreData

/// Manages the CoreData stack with a programmatic model (no .xcdatamodeld binary).
/// Also provides JSON export/import for all user data.
public final class PersistenceController {

    public static let shared = PersistenceController()

    public let container: NSPersistentContainer

    private init() {
        // Build model programmatically — no .xcdatamodeld needed
        let model = NSManagedObjectModel()
        model.entities = [
            FocusSession.entityDescription(),
            TaskItem.entityDescription(),
        ]

        container = NSPersistentContainer(name: "FocusFlip", managedObjectModel: model)

        Self.migrateLegacyStoreIfNeeded()

        let storeURL = Self.dataStoreURL()
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                NSLog("[FocusFlip] CoreData load error: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public var viewContext: NSManagedObjectContext { container.viewContext }

    /// App Group shared with the widget extension.
    public static let appGroupID = "group.com.focusflip.app"

    // MARK: - Store location

    /// Store lives in the App Group container so the widget extension can read
    /// the same data. Falls back to Application Support if the group is
    /// unavailable (e.g. entitlements stripped).
    public static func dataStoreURL() -> URL {
        let fm = FileManager.default
        let dir: URL
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            dir = groupURL.appendingPathComponent("FocusFlip", isDirectory: true)
        } else {
            let appSupport = try! fm.url(for: .applicationSupportDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: true)
            dir = appSupport.appendingPathComponent("FocusFlip", isDirectory: true)
        }
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("FocusFlip.sqlite")
    }

    /// v1.0.x stored data in Application Support. Copy it into the App Group
    /// container once so existing users keep their history after this update.
    private static func migrateLegacyStoreIfNeeded() {
        let fm = FileManager.default
        let newStore = dataStoreURL()
        guard !fm.fileExists(atPath: newStore.path) else { return }

        let appSupport = (try? fm.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)) ?? newStore.deletingLastPathComponent()
        let legacyDir = appSupport.appendingPathComponent("FocusFlip", isDirectory: true)
        let legacyStore = legacyDir.appendingPathComponent("FocusFlip.sqlite")
        guard fm.fileExists(atPath: legacyStore.path) else { return }

        do {
            try fm.createDirectory(at: newStore.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try fm.copyItem(at: legacyStore, to: newStore)
            // Copy sidecar files if present (WAL mode)
            for suffix in ["-wal", "-shm"] {
                let src = URL(fileURLWithPath: legacyStore.path + suffix)
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: URL(fileURLWithPath: newStore.path + suffix))
                }
            }
            NSLog("[FocusFlip] Migrated legacy store to App Group container")
        } catch {
            NSLog("[FocusFlip] Store migration error: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD helpers

    public func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            NSLog("[FocusFlip] Save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Session queries

    public func fetchSessions(for date: Date) -> [FocusSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let req: NSFetchRequest<FocusSession> = FocusSession.fetchRequest()
        req.predicate = NSPredicate(format: "startDate >= %@ AND startDate < %@", start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        return (try? container.viewContext.fetch(req)) ?? []
    }

    public func fetchAllSessions() -> [FocusSession] {
        let req: NSFetchRequest<FocusSession> = FocusSession.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return (try? container.viewContext.fetch(req)) ?? []
    }

    public func fetchTasks() -> [TaskItem] {
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return (try? container.viewContext.fetch(req)) ?? []
    }

    // MARK: - Record a session

    public func recordSession(type: SessionType, duration: Int, taskId: UUID? = nil) {
        let ctx = container.viewContext
        let session = FocusSession(context: ctx)
        session.id = UUID()
        session.startDate = Date().addingTimeInterval(TimeInterval(-duration))
        session.endDate = Date()
        session.durationSeconds = Int32(duration)
        session.typeRaw = type.rawValue
        session.completed = true
        session.taskId = taskId

        // If linked to a task, increment its pomodoro count
        if let taskId = taskId, let task = fetchTask(id: taskId), type == .focus {
            task.completedPomodoros += 1
            if task.isDone { task.completed = true }
        }

        save()
    }

    public func fetchTask(id: UUID) -> TaskItem? {
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id.uuidString as NSString)
        req.fetchLimit = 1
        return try? container.viewContext.fetch(req).first
    }

    // MARK: - JSON Export / Import

    public struct ExportData: Codable {
        public let sessions: [SessionExport]
        public let tasks: [TaskExport]
        public let exportDate: Date
        public let appVersion: String
    }

    public struct SessionExport: Codable {
        public let id: UUID
        public let startDate: Date
        public let endDate: Date
        public let durationSeconds: Int
        public let type: String
        public let taskId: UUID?
    }

    public struct TaskExport: Codable {
        public let id: UUID
        public let title: String
        public let note: String
        public let createdAt: Date
        public let completed: Bool
        public let estimatedPomodoros: Int
        public let completedPomodoros: Int
    }

    public func exportJSON() throws -> Data {
        let sessions = fetchAllSessions().map {
            SessionExport(id: $0.id, startDate: $0.startDate, endDate: $0.endDate,
                          durationSeconds: Int($0.durationSeconds), type: $0.typeRaw, taskId: $0.taskId)
        }
        let tasks = fetchTasks().map {
            TaskExport(id: $0.id, title: $0.title, note: $0.note, createdAt: $0.createdAt,
                       completed: $0.completed, estimatedPomodoros: Int($0.estimatedPomodoros),
                       completedPomodoros: Int($0.completedPomodoros))
        }
        let export = ExportData(sessions: sessions, tasks: tasks,
                                exportDate: Date(), appVersion: "1.0.0")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    public func exportToURL() throws -> URL {
        let data = try exportJSON()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusFlip_Export_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }
}
