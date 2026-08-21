import Foundation
import CoreData

// MARK: - 实体

@objc(TaskEntity)
final class TaskEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var colorHex: String
    @NSManaged var sortOrder: Int32
    @NSManaged var createdAt: Date
    @NSManaged var isDone: Bool

    static func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }
}

@objc(SessionEntity)
final class SessionEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var phaseRaw: String          // focus | shortBreak | longBreak
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var durationSeconds: Int32
    @NSManaged var completed: Bool
    @NSManaged var taskId: UUID?
    @NSManaged var note: String?

    static func fetchRequest() -> NSFetchRequest<SessionEntity> {
        NSFetchRequest<SessionEntity>(entityName: "SessionEntity")
    }
}

@objc(CountdownEntity)
final class CountdownEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var targetDate: Date
    @NSManaged var colorHex: String
    @NSManaged var createdAt: Date

    static func fetchRequest() -> NSFetchRequest<CountdownEntity> {
        NSFetchRequest<CountdownEntity>(entityName: "CountdownEntity")
    }
}

// MARK: - 存储栈（全新独立存储，不继承旧数据）

final class Store {

    static let shared = Store()
    let container: NSPersistentContainer

    private init() {
        let model = NSManagedObjectModel()
        model.entities = [Self.taskEntity(), Self.sessionEntity(), Self.countdownEntity()]
        container = NSPersistentContainer(name: "FlowSim", managedObjectModel: model)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlowSim", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        container.persistentStoreDescriptions = [
            NSPersistentStoreDescription(url: dir.appendingPathComponent("FlowSim.sqlite"))
        ]
        container.loadPersistentStores { _, error in
            if let error { NSLog("[FlowSim] store error: \(error.localizedDescription)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext { container.viewContext }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    // MARK: 任务

    func tasks() -> [TaskEntity] {
        let req: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    @discardableResult
    func addTask(name: String) -> TaskEntity {
        let t = TaskEntity(context: context)
        t.id = UUID()
        t.name = name
        let count = tasks().count
        t.colorHex = Palette.taskPalette[count % Palette.taskPalette.count]
        t.sortOrder = Int32(count)
        t.createdAt = Date()
        save()
        return t
    }

    func deleteTask(_ task: TaskEntity) {
        context.delete(task)
        save()
    }

    func task(id: UUID?) -> TaskEntity? {
        guard let id else { return nil }
        let req: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    func setDone(_ task: TaskEntity, _ done: Bool) {
        task.isDone = done
        save()
    }

    // MARK: 会话

    func record(phase: Phase, seconds: Int, start: Date, completed: Bool, taskId: UUID?) {
        let s = SessionEntity(context: context)
        s.id = UUID()
        s.phaseRaw = phase.rawValue
        s.startDate = start
        s.endDate = Date()
        s.durationSeconds = Int32(seconds)
        s.completed = completed
        s.taskId = taskId
        save()
    }

    func todayFocusCount() -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "phaseRaw == %@ AND startDate >= %@ AND completed == YES",
                                    Phase.focus.rawValue, start as NSDate)
        return (try? context.count(for: req)) ?? 0
    }

    // MARK: 会话备注

    func setNote(_ session: SessionEntity, _ note: String?) {
        session.note = (note?.isEmpty ?? true) ? nil : note
        save()
    }

    // MARK: 倒计时

    func countdowns() -> [CountdownEntity] {
        let req: NSFetchRequest<CountdownEntity> = CountdownEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "targetDate", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    @discardableResult
    func addCountdown(title: String, date: Date, colorHex: String) -> CountdownEntity {
        let c = CountdownEntity(context: context)
        c.id = UUID(); c.title = title; c.targetDate = date
        c.colorHex = colorHex; c.createdAt = Date()
        save(); return c
    }

    func deleteCountdown(_ c: CountdownEntity) {
        context.delete(c); save()
    }

    // MARK: 程序化模型

    private static func attr(_ name: String, _ type: NSAttributeType, _ optional: Bool) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = type; a.isOptional = optional
        return a
    }

    private static func taskEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "TaskEntity"
        e.managedObjectClassName = NSStringFromClass(TaskEntity.self)
        e.properties = [
            attr("id", .UUIDAttributeType, false),
            attr("name", .stringAttributeType, false),
            attr("colorHex", .stringAttributeType, false),
            attr("sortOrder", .integer32AttributeType, false),
            attr("createdAt", .dateAttributeType, false),
            attr("isDone", .booleanAttributeType, false),
        ]
        e.properties.last?.defaultValue = false
        return e
    }

    private static func countdownEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CountdownEntity"
        e.managedObjectClassName = NSStringFromClass(CountdownEntity.self)
        e.properties = [
            attr("id", .UUIDAttributeType, false),
            attr("title", .stringAttributeType, false),
            attr("targetDate", .dateAttributeType, false),
            attr("colorHex", .stringAttributeType, false),
            attr("createdAt", .dateAttributeType, false),
        ]
        return e
    }

    private static func sessionEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "SessionEntity"
        e.managedObjectClassName = NSStringFromClass(SessionEntity.self)
        e.properties = [
            attr("id", .UUIDAttributeType, false),
            attr("phaseRaw", .stringAttributeType, false),
            attr("startDate", .dateAttributeType, false),
            attr("endDate", .dateAttributeType, false),
            attr("durationSeconds", .integer32AttributeType, false),
            attr("completed", .booleanAttributeType, false),
            attr("taskId", .UUIDAttributeType, true),
            attr("note", .stringAttributeType, true),
        ]
        return e
    }
}
