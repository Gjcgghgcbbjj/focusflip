import Foundation
import CoreData

/// A user-defined task that focus sessions can be linked to.
@objc(TaskItem)
public final class TaskItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var note: String
    @NSManaged public var createdAt: Date
    @NSManaged public var completed: Bool
    @NSManaged public var estimatedPomodoros: Int32
    @NSManaged public var completedPomodoros: Int32
    @NSManaged public var sortOrder: Int32
    @NSManaged public var colorHex: String

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    var progress: Double {
        guard estimatedPomodoros > 0 else { return 0 }
        return Double(completedPomodoros) / Double(estimatedPomodoros)
    }

    var isDone: Bool { completedPomodoros >= estimatedPomodoros && estimatedPomodoros > 0 }
}

extension TaskItem {
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        entity.managedObjectClassName = NSStringFromClass(TaskItem.self)

        let attrs: [(String, NSAttributeType, Bool)] = [
            ("id",                 .UUIDAttributeType,      false),
            ("title",              .stringAttributeType,    false),
            ("note",               .stringAttributeType,    false),
            ("createdAt",          .dateAttributeType,      false),
            ("completed",          .booleanAttributeType,   false),
            ("estimatedPomodoros", .integer32AttributeType, false),
            ("completedPomodoros", .integer32AttributeType, false),
            ("sortOrder",          .integer32AttributeType, false),
            ("colorHex",           .stringAttributeType,    false),
        ]

        entity.properties = attrs.map { name, type, optional in
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            return attr
        }
        return entity
    }
}
