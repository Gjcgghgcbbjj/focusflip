import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreData

/// 全量 JSON 备份 / 恢复（按 ID 去重合并）
enum Backup {

    // MARK: 模型

    struct Task: Codable {
        var id: UUID
        var name: String
        var colorHex: String
        var isDone: Bool
        var sortOrder: Int
    }
    struct Countdown: Codable {
        var title: String
        var date: Date
        var colorHex: String
        var createdAt: Date
    }
    struct Session: Codable {
        var id: UUID
        var start: Date
        var end: Date
        var seconds: Int
        var completed: Bool
        var phaseRaw: String
        var taskId: UUID?
        var note: String?
    }
    struct Payload: Codable {
        var version = 1
        var exportedAt = Date()
        var tasks: [Task]
        var countdowns: [Countdown]
        var sessions: [Session]
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .formatted(iso)
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
    private static func decoder() -> JSONDecoder {
        let dnc = JSONDecoder()
        dnc.dateDecodingStrategy = .formatted(iso)
        return dnc
    }

    // MARK: 导出

    @discardableResult
    static func make() -> URL? {
        let store = Store.shared

        let tasks: [Task] = store.tasks().map {
            Task(id: $0.id, name: $0.name, colorHex: $0.colorHex,
                 isDone: $0.isDone, sortOrder: Int($0.sortOrder))
        }
        let cds: [Countdown] = store.countdowns().map {
            Countdown(title: $0.title, date: $0.targetDate,
                      colorHex: $0.colorHex, createdAt: $0.createdAt)
        }
        let ses: [Session] = fetchSessions().map {
            Session(id: $0.id, start: $0.startDate, end: $0.endDate,
                    seconds: Int($0.durationSeconds), completed: $0.completed,
                    phaseRaw: $0.phaseRaw, taskId: $0.taskId, note: $0.note)
        }

        let payload = Payload(tasks: tasks, countdowns: cds, sessions: ses)
        do {
            let data = try encoder().encode(payload)
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd_HHmm"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("FocusFlip_备份_\(df.string(from: Date())).json")
            try data.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            NSLog("[Backup] export error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: 导入（按 ID 去重合并）

    /// 返回新增条数；-1 表示失败
    static func restore(from url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let payload = try? decoder().decode(Payload.self, from: data) else { return -1 }

        let store = Store.shared
        var added = 0

        // 任务（按 id 去重）
        let existingTaskIds = Set(store.tasks().map { $0.id })
        for t in payload.tasks where !existingTaskIds.contains(t.id) {
            if let nt = store.addTaskRaw(name: t.name, colorHex: t.colorHex) {
                nt.id = t.id
                nt.isDone = t.isDone
                nt.sortOrder = Int32(t.sortOrder)
                added += 1
            }
        }
        store.save()

        // 目标（无 id，按 title+date 去重）
        let existingCd = Set(store.countdowns().map { "\($0.title)|\(Int($0.targetDate.timeIntervalSince1970))" })
        for c in payload.countdowns {
            let key = "\(c.title)|\(Int(c.date.timeIntervalSince1970))"
            if !existingCd.contains(key) {
                _ = store.addCountdown(title: c.title, date: c.date, colorHex: c.colorHex)
                added += 1
            }
        }

        // 记录（按 id 去重）
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        let existingSes = Set(((try? store.context.fetch(req)) ?? []).map { $0.id })
        for s in payload.sessions where !existingSes.contains(s.id) {
            let se = SessionEntity(context: store.context)
            se.id = s.id
            se.startDate = s.start
            se.endDate = s.end
            se.durationSeconds = Int64(s.seconds)
            se.completed = s.completed
            se.phaseRaw = s.phaseRaw
            se.taskId = s.taskId
            se.note = s.note
            added += 1
        }
        store.save()
        return added
    }

    private static func fetchSessions() -> [SessionEntity] {
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        return (try? Store.shared.context.fetch(req)) ?? []
    }
}
