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

        // --- 右滑删除「读书」：决定性全扫；被识别成 tap（开编辑页）就关掉重试 ---
        let reading = app.staticTexts["读书"]
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        var deleted = false
        var tapMisfires = 0
        for _ in 1...3 {
            let start = reading.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
            let end = reading.coordinate(withNormalizedOffset: CGVector(dx: -0.6, dy: 0.5))
            start.press(forDuration: 0.01, thenDragTo: end,
                        withVelocity: .fast, thenHoldForDuration: 0.08)
            let editSheet = app.navigationBars["编辑任务"]
            if editSheet.exists {
                tapMisfires += 1
                app.buttons["关闭"].firstMatch.tap()
                _ = app.staticTexts["读书"].waitForExistence(timeout: 3)
                continue
            }
            let deleteBtn = app.buttons["删除"].firstMatch
            if deleteBtn.waitForExistence(timeout: 1.5) {
                deleteBtn.tap()
                deleted = true
                break
            }
            if !reading.exists { deleted = true; break }   // 全扫直接删除的情况
        }
        if !deleted { deleted = !reading.exists }
        XCTAssertTrue(deleted, "右滑删除未生效（被误识别为点击 \(tapMisfires) 次）")
        XCTAssertEqual(app.state, .runningForeground, "右滑删除后 app 存活")

        // --- 撤销（Toast）---
        let undo = app.buttons["撤销"]
        if undo.waitForExistence(timeout: 3) {
            undo.tap()
            XCTAssertTrue(app.staticTexts["读书"].waitForExistence(timeout: 5), "撤销后应恢复")
            XCTAssertEqual(app.state, .runningForeground, "撤销后 app 存活")
        }

        // --- 左滑「运动」设为当前 ---
        let sport = app.staticTexts["运动"]
        XCTAssertTrue(sport.waitForExistence(timeout: 5))
        sport.swipeRight()
        let setCurrent = app.buttons["设为当前"].firstMatch
        if setCurrent.waitForExistence(timeout: 2) {
            setCurrent.tap()
            let editSheet = app.navigationBars["编辑任务"]
            if editSheet.waitForExistence(timeout: 2) {
                XCTFail("点「设为当前」误开编辑页 —— 行 tap 手势抢点击")
                app.buttons["关闭"].firstMatch.tap()
                return
            }
        }
        XCTAssertEqual(app.state, .runningForeground, "左滑设当前后 app 存活")

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
