import Foundation
import AVFoundation
import Combine
import UserNotifications

// MARK: - 后台保活（静音循环 + 1s tick）

final class KeepAlive {

    static let shared = KeepAlive()

    static let tickPublisher = PassthroughSubject<Void, Never>()

    private var timer: DispatchSourceTimer?
    private var player: AVAudioPlayer?

    func start() {
        stopTick()
        activateAudio()
        startTick()
    }

    func stop() {
        stopTick()
        deactivateAudio()
    }

    private func startTick() {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        t.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))
        t.setEventHandler { Self.tickPublisher.send() }
        t.resume()
        timer = t
    }

    private func stopTick() {
        timer?.cancel()
        timer = nil
    }

    private func activateAudio() {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(data: Self.silentWAV())
            player?.numberOfLoops = -1
            player?.volume = 0.01
            player?.play()
        } catch {
            NSLog("[FlowSim] keepalive audio error: \(error.localizedDescription)")
        }
    }

    private func deactivateAudio() {
        player?.stop()
        player = nil
    }

    /// 1 秒静音 WAV（内存合成）
    private static func silentWAV() -> Data {
        let sampleRate = 44_100
        let dataLength = sampleRate * 2          // 16-bit mono
        var header = Data()
        func str(_ s: String) { header.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }

        str("RIFF"); u32(UInt32(36 + dataLength)); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2))
        u16(2); u16(16)
        str("data"); u32(UInt32(dataLength))
        header.append(Data(count: dataLength))
        return header
    }
}

// MARK: - 完成通知

enum Notifications {

    static let actionStartNext = "START_NEXT"
    private static let focusDoneCategory = "FOCUS_DONE"
    private static let breakDoneCategory = "BREAK_DONE"

    /// 通知操作按钮：专注完成→[开始休息]；休息结束→[开始专注]。冷启动/前台都走 delegate
    static func registerCategories() {
        let startNext = UNNotificationAction(identifier: actionStartNext,
                                             title: "开始下一阶段",
                                             options: [.foreground])
        let focusCat = UNNotificationCategory(identifier: focusDoneCategory,
                                              actions: [startNext], intentIdentifiers: [])
        let breakCat = UNNotificationCategory(identifier: breakDoneCategory,
                                              actions: [startNext], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([focusCat, breakCat])
    }

    static func requestOnce() {
        let key = "notifAsked"
        let first = !UserDefaults.standard.bool(forKey: key)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    // 只在首次同步结果，永不覆盖用户在 App 内的开关意图
                    if first {
                        UserDefaults.standard.set(granted, forKey: "notifEnabled")
                        UserDefaults.standard.set(true, forKey: key)
                    }
                }
            }
    }

    static func scheduleCountdown(in seconds: Int) {
        guard UserDefaults.standard.object(forKey: "notifEnabled") as? Bool ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = "时间到 ⏰"
        content.body = "倒计时结束，回来看看吧"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "freetimer-countdown", content: content, trigger: trigger))
    }

    /// 只取消自由倒计时自己的待发通知——绝不碰番茄引擎的（cancelAll 误伤事故）
    static func cancelCountdown() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["freetimer-countdown"])
    }

    static func schedule(in seconds: Int, phase: Phase, taskName: String?) {
        guard UserDefaults.standard.object(forKey: "notifEnabled") as? Bool ?? true else { return }

        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "专注完成 🎉"
            content.body = taskName.map { "「\($0)」完成了一个番茄，休息一下吧" }
                ?? "完成了一个番茄，休息一下吧"
        case .shortBreak:
            content.title = "小憩结束"; content.body = "回去继续专注"
        case .longBreak:
            content.title = "长歇结束"; content.body = "充好电了，开始下一轮"
        }
        content.sound = .default
        content.categoryIdentifier = phase == .focus ? focusDoneCategory : breakDoneCategory

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
    }

    /// 目标倒计时提醒：目标日前几天早上 9 点
    static func scheduleTargetReminder(id: UUID, title: String, targetDate: Date, daysBefore: Int) {
        cancelTargetReminder(id: id)
        guard daysBefore > 0,
              UserDefaults.standard.object(forKey: "notifEnabled") as? Bool ?? true else { return }
        var fire = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        fire = Calendar.current.date(byAdding: .day, value: -daysBefore, to: fire) ?? fire
        guard fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "🎯 \(title)"
        content.body = daysBefore == 1 ? "明天就是目标日，最后冲刺！" : "还有 \(daysBefore) 天，加油"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "target-\(id.uuidString)", content: content, trigger: trigger))
    }

    static func cancelTargetReminder(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["target-\(id.uuidString)"])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
