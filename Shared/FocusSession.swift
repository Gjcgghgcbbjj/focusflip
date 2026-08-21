import Foundation
import CoreData

/// A single pomodoro focus/break session record, persisted in CoreData.
@objc(FocusSession)
public final class FocusSession: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
    @NSManaged public var durationSeconds: Int32
    @NSManaged public var typeRaw: String      // "focus" | "shortBreak" | "longBreak"
    @NSManaged public var completed: Bool
    @NSManaged public var taskId: UUID?        // optional linked task
    @NSManaged public var note: String?
    @NSManaged public var interruptReason: String?  // why an unfinished focus was skipped

    public var sessionType: SessionType {
        get { SessionType(rawValue: typeRaw) ?? .focus }
        set { typeRaw = newValue.rawValue }
    }

    public var durationMinutes: Double {
        Double(durationSeconds) / 60.0
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FocusSession> {
        NSFetchRequest<FocusSession>(entityName: "FocusSession")
    }
}

public enum SessionType: String, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    public var displayName: String {
        switch self {
        case .focus:       return "专注"
        case .shortBreak:  return "短休息"
        case .longBreak:   return "长休息"
        }
    }

    public var iconName: String {
        switch self {
        case .focus:       return "brain.head.profile"
        case .shortBreak:  return "cup.and.saucer"
        case .longBreak:   return "leaf"
        }
    }
}

// MARK: - CoreData Entity Description (programmatic, no .xcdatamodeld needed)

extension FocusSession {
    /// Build the NSEntityDescription programmatically so we avoid shipping a
    /// binary .xcdatamodeld file (hard to compile with theos toolchain).
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "FocusSession"
        entity.managedObjectClassName = NSStringFromClass(FocusSession.self)

        let attrs: [(String, NSAttributeType, Bool)] = [
            ("id",              .UUIDAttributeType,    false),
            ("startDate",       .dateAttributeType,    false),
            ("endDate",         .dateAttributeType,    false),
            ("durationSeconds", .integer32AttributeType, false),
            ("typeRaw",         .stringAttributeType,  false),
            ("completed",       .booleanAttributeType, false),
            ("taskId",          .UUIDAttributeType,    true),
            ("note",            .stringAttributeType,  true),
            ("interruptReason", .stringAttributeType,  true),
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
