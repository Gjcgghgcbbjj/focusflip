import Foundation
import CoreData
#if canImport(WidgetKit)
import WidgetKit
#endif

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
            HabitItem.entityDescription(),
            HabitCheck.entityDescription(),
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

    public func recordSession(type: SessionType, duration: Int, taskId: UUID? = nil,
                              startDate: Date? = nil, interruptReason: String? = nil) {
        let ctx = container.viewContext
        let session = FocusSession(context: ctx)
        session.id = UUID()
        session.startDate = startDate ?? Date().addingTimeInterval(TimeInterval(-duration))
        session.endDate = Date()
        session.durationSeconds = Int32(duration)
        session.typeRaw = type.rawValue
        session.completed = true
        session.taskId = taskId
        session.interruptReason = interruptReason

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
                                exportDate: Date(), appVersion: currentVersion)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    public func exportToURL() throws -> URL {
        let data = try exportJSON()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusFlip_Export_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }

    // MARK: - JSON Import / Clear

    /// Import an exported JSON file. Upserts by id — existing records are kept,
    /// new ones are added, so importing is safe to repeat.
    // MARK: - Auto backup (rolling 7 days, Documents/FocusFlipBackups)

    /// Writes a JSON snapshot into Documents/FocusFlipBackups (keeps newest 7).
    /// Called when the app goes to background; skips if already backed up today.
    public func autoBackupIfNeeded() {
        let d = UserDefaults.standard
        let key = "lastAutoBackupDay"
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        if let last = d.object(forKey: key) as? Double, last == today { return }

        do {
            let data = try exportJSON()
            let dir = Self.backupDirectory()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            try data.write(to: dir.appendingPathComponent("FocusFlip-\(stamp).json"), options: .atomic)

            // Prune to newest 7 files
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]))?
                .filter { $0.pathExtension == "json" }
                .sorted {
                    (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        ?? .distantPast
                    >
                    (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        ?? .distantPast
                } ?? []
            if files.count > 7 {
                for old in files.dropFirst(7) { try? FileManager.default.removeItem(at: old) }
            }

            d.set(today, forKey: key)
        } catch {
            NSLog("[FocusFlip] Auto backup failed: \(error.localizedDescription)")
        }
    }

    public static func backupDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusFlipBackups", isDirectory: true)
    }

    public var lastBackupLabel: String? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.backupDirectory(), includingPropertiesForKeys: nil),
              let newest = files.filter({ $0.pathExtension == "json" })
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else { return nil }
        return newest.lastPathComponent
    }

    // MARK: - CSV export (session detail for spreadsheets)

    public func exportCSV() throws -> URL {
        let sessions = fetchAllSessions().sorted { $0.startDate < $1.startDate }
        var tasksById: [UUID: String] = [:]
        fetchTasks().forEach { tasksById[$0.id] = $0.title }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var rows = ["开始时间,结束时间,类型,时长(分钟),完成,任务,打断原因"]
        for s in sessions {
            let task = s.taskId.flatMap { tasksById[$0] } ?? ""
            let reason = (s.interruptReason ?? "").replacingOccurrences(of: ",", with: " ")
            rows.append([
                df.string(from: s.startDate),
                df.string(from: s.endDate),
                s.sessionType.displayName,
                String(Int(s.durationSeconds) / 60),
                s.completed ? "是" : "否",
                task.replacingOccurrences(of: ",", with: " "),
                reason,
            ].joined(separator: ","))
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusFlip-\(Int(Date().timeIntervalSince1970)).csv")
        try rows.joined(separator: "\n").data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    public func importJSON(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(ExportData.self, from: data)

        let ctx = container.viewContext

        // Existing ids for dedup
        let existingSessionIds = Set(fetchAllSessions().compactMap { $0.id })
        let existingTaskIds = Set(fetchTasks().compactMap { $0.id })

        for s in export.sessions {
            guard !existingSessionIds.contains(s.id) else { continue }
            let session = FocusSession(context: ctx)
            session.id = s.id
            session.startDate = s.startDate
            session.endDate = s.endDate
            session.durationSeconds = Int32(s.durationSeconds)
            session.typeRaw = s.type
            session.completed = true
            session.taskId = s.taskId
        }

        for t in export.tasks {
            guard !existingTaskIds.contains(t.id) else { continue }
            let task = TaskItem(context: ctx)
            task.id = t.id
            task.title = t.title
            task.note = t.note
            task.createdAt = t.createdAt
            task.completed = t.completed
            task.estimatedPomodoros = Int32(t.estimatedPomodoros)
            task.completedPomodoros = Int32(t.completedPomodoros)
            task.sortOrder = 0
            task.colorHex = "#FF6B6B"
        }

        save()
        refreshWidgets()
    }

    /// Delete every session and task (destructive — callers must confirm).
    public func clearAllData() {
        let ctx = container.viewContext
        let reqS: NSFetchRequest<NSFetchRequestResult> =
            FocusSession.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>
        let reqT: NSFetchRequest<NSFetchRequestResult> =
            TaskItem.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>
        try? ctx.execute(NSBatchDeleteRequest(fetchRequest: reqS))
        try? ctx.execute(NSBatchDeleteRequest(fetchRequest: reqT))
        try? ctx.save()
        ctx.reset()
        refreshWidgets()
    }

    /// Tell the home-screen widget to reload after data changes.
    private func refreshWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
