import XCTest

/// 任务页交互复现环 —— 真机反馈「左滑/右滑/添加/删除 闪退+动画不对」。
/// 在 CI 模拟器上驱动同一组手势；app 一崩测试即红，堆栈进 xcresult/DiagnosticReports。
final class TodoInteractionTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FF_SEED_DEMO"] = "1"   // 种 3 任务：写代码/读书/运动
        app.launchEnvironment["FF_UI_TOUR"] = "1"     // 跳过通知权限弹窗
        app.launch()
    }

    /// 主叙事：右滑删除 → 撤销 → 左滑设当前 → 快捷开始 → 添加 → 编辑
    func testSwipeAddDeleteFlow() throws {
        // 进任务页
        let tasksTab = app.tabBars.buttons["任务"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 10), "tab bar 未出现")
        tasksTab.tap()

        // 种子任务可见
        let coding = app.staticTexts["写代码"]
        XCTAssertTrue(coding.waitForExistence(timeout: 8), "种子任务「写代码」未出现")

        // --- 右滑删除「读书」：整卡坐标决定性全扫（文本坐标拖距太小只会露出）---
        let readingCard = app.buttons["task.card.读书"]
        XCTAssertTrue(readingCard.waitForExistence(timeout: 5))
        var deleted = false
        var tapMisfires = 0
        for _ in 1...3 {
            let start = readingCard.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            let end = readingCard.coordinate(withNormalizedOffset: CGVector(dx: -0.4, dy: 0.5))
            start.press(forDuration: 0.01, thenDragTo: end,
                        withVelocity: .fast, thenHoldForDuration: 0.08)
            let editSheet = app.navigationBars["编辑任务"]
            if editSheet.exists {
                tapMisfires += 1
                app.buttons["关闭"].firstMatch.tap()
                _ = readingCard.waitForExistence(timeout: 3)
                continue
            }
            // 全扫直接删除：卡片飞出 + 离场动画，给足消失窗口
            if !readingCard.waitForExistence(timeout: 2) { deleted = true; break }
        }
        if !deleted { deleted = !readingCard.exists }
        XCTAssertTrue(deleted, "右滑删除未生效（被误识别为点击 \(tapMisfires) 次）")
        XCTAssertEqual(app.state, .runningForeground, "右滑删除后 app 存活")

        // --- 撤销（Toast）---
        let undo = app.buttons["撤销"]
        if undo.waitForExistence(timeout: 3) {
            undo.tap()
            XCTAssertTrue(readingCard.waitForExistence(timeout: 5), "撤销后应恢复")
            XCTAssertEqual(app.state, .runningForeground, "撤销后 app 存活")
        }

        // --- 右滑「运动」设为当前：整卡坐标越过阈值，直接触发不经按钮 ---
        let sportCard = app.buttons["task.card.运动"]
        XCTAssertTrue(sportCard.waitForExistence(timeout: 5))
        let sStart = sportCard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
        let sEnd = sportCard.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        sStart.press(forDuration: 0.01, thenDragTo: sEnd,
                     withVelocity: .fast, thenHoldForDuration: 0.08)
        XCTAssertEqual(app.state, .runningForeground, "左滑设当前后 app 存活")
        XCTAssertTrue(app.staticTexts["运动"].waitForExistence(timeout: 3))

        // --- 卡片快捷开始（▶︎）：嵌套按钮对 XCUITest 不可 hittable，走坐标点击（真实触摸语义）---
        let play = app.buttons["开始这个任务"].firstMatch
        if play.waitForExistence(timeout: 3) {
            play.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertEqual(app.state, .runningForeground, "快捷开始后 app 存活")
            let focusTab = app.tabBars.buttons["专注"]
            XCTAssertTrue(focusTab.waitForExistence(timeout: 5), "快捷开始应跳到专注页")
            focusTab.tap()   // 回任务页继续
            _ = app.staticTexts["写代码"].waitForExistence(timeout: 5)
        }

        // --- 添加任务：冷启动直达任务页（FF_TAB 确定性导航，不跟 tab 手势纠缠）---
        app.terminate()
        app.launchEnvironment["FF_TAB"] = "tasks"
        app.launch()
        let add = app.buttons["todo.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "未找到 + 按钮")
        XCTAssertTrue(add.isHittable, "+ 按钮不可点击")
        add.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 6), "添加页输入框未出现")
        field.tap()
        field.typeText("测试任务A")
        let addBtn = app.buttons["添加"].firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 3))
        addBtn.tap()
        XCTAssertTrue(app.staticTexts["测试任务A"].waitForExistence(timeout: 6),
                      "添加后新卡片应出现")
        XCTAssertEqual(app.state, .runningForeground, "添加后 app 存活")

        // --- 点卡片进编辑再关闭 ---
        let newCard = app.staticTexts["测试任务A"]
        newCard.tap()
        let editTitle = app.navigationBars["编辑任务"]
        if editTitle.waitForExistence(timeout: 4) {
            let close = app.buttons["关闭"]
            if close.waitForExistence(timeout: 3) { close.tap() }
        }
        XCTAssertEqual(app.state, .runningForeground, "编辑关闭后 app 存活")
    }
}
