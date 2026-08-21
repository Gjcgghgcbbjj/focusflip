import Foundation
import CoreData

// MARK: - Habit (每日习惯打卡)

@objc(HabitItem)
public final class HabitItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var colorHex: String
    @NSManaged public var createdAt: Date
    @NSManaged public var archived: Bool
    @NSManaged public var sortOrder: Int32

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HabitItem> {
        NSFetchRequest<HabitItem>(entityName: "HabitItem")
    }
}

// MARK: - HabitCheck (某天打了卡)

@objc(HabitCheck)
public final class HabitCheck: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var habitId: UUID
    /// 归一化到当天 00:00，方便按日查询与连击计算
    @NSManaged public var day: Date

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HabitCheck> {
        NSFetchRequest<HabitCheck>(entityName: "HabitCheck")
    }
}

// MARK: - Entity descriptions (programmatic model)

extension HabitItem {
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "HabitItem"
        entity.managedObjectClassName = NSStringFromClass(HabitItem.self)

        let attrs: [(String, NSAttributeType, Bool)] = [
            ("id",        .UUIDAttributeType,   false),
            ("name",      .stringAttributeType, false),
            ("colorHex",  .stringAttributeType, false),
            ("createdAt", .dateAttributeType,   false),
            ("archived",  .booleanAttributeType, false),
            ("sortOrder", .integer32AttributeType, false),
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

extension HabitCheck {
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "HabitCheck"
        entity.managedObjectClassName = NSStringFromClass(HabitCheck.self)

        let attrs: [(String, NSAttributeType, Bool)] = [
            ("id",      .UUIDAttributeType,  false),
            ("habitId", .UUIDAttributeType,  false),
            ("day",     .dateAttributeType,  false),
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

// MARK: - Habit helpers on PersistenceController

extension PersistenceController {

    public func fetchHabits(includeArchived: Bool = false) -> [HabitItem] {
        let req: NSFetchRequest<HabitItem> = HabitItem.fetchRequest()
        if !includeArchived {
            req.predicate = NSPredicate(format: "archived == NO")
        }
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return (try? container.viewContext.fetch(req)) ?? []
    }

    public func habitCheckedToday(_ habit: HabitItem) -> Bool {
        isHabit(habit, checkedOn: Date())
    }

    public func isHabit(_ habit: HabitItem, checkedOn date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let req: NSFetchRequest<HabitCheck> = HabitCheck.fetchRequest()
        req.predicate = NSPredicate(format: "habitId == %@ AND day == %@",
                                    habit.id as CVarArg, day as NSDate)
        req.fetchLimit = 1
        return ((try? container.viewContext.fetch(req))?.first) != nil
    }

    /// Toggle today's check-in. Returns the new state.
    @discardableResult
    public func toggleHabitToday(_ habit: HabitItem) -> Bool {
        toggleHabit(habit, on: Date())
    }

    @discardableResult
    public func toggleHabit(_ habit: HabitItem, on date: Date) -> Bool {
        let ctx = container.viewContext
        let day = Calendar.current.startOfDay(for: date)
        let req: NSFetchRequest<HabitCheck> = HabitCheck.fetchRequest()
        req.predicate = NSPredicate(format: "habitId == %@ AND day == %@",
                                    habit.id as CVarArg, day as NSDate)
        req.fetchLimit = 1

        if let existing = try? ctx.fetch(req).first {
            ctx.delete(existing)
            save()
            return false
        } else {
            let check = HabitCheck(context: ctx)
            check.id = UUID()
            check.habitId = habit.id
            check.day = day
            save()
            return true
        }
    }

    /// Consecutive days ending today (or yesterday if today not yet checked).
    public func habitStreak(_ habit: HabitItem) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 0
        var date = habitCheckedToday(habit)
            ? today
            : cal.date(byAdding: .day, value: -1, to: today)!
        while isHabit(habit, checkedOn: date) {
            streak += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return streak
    }

    /// Number of checks in the current week (week starts Monday).
    public func habitChecksThisWeek(_ habit: HabitItem) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) + 5) % 7   // 周一=0
        guard let weekStart = cal.date(byAdding: .day, value: -weekday, to: today) else { return 0 }
        let req: NSFetchRequest<HabitCheck> = HabitCheck.fetchRequest()
        req.predicate = NSPredicate(format: "habitId == %@ AND day >= %@",
                                    habit.id as CVarArg, weekStart as NSDate)
        return (try? container.viewContext.count(for: req)) ?? 0
    }

    public func deleteHabit(_ habit: HabitItem) {
        let ctx = container.viewContext
        // Cascade delete checks
        let req: NSFetchRequest<HabitCheck> = HabitCheck.fetchRequest()
        req.predicate = NSPredicate(format: "habitId == %@", habit.id as CVarArg)
        (try? ctx.fetch(req))?.forEach { ctx.delete($0) }
        ctx.delete(habit)
        save()
    }
}
