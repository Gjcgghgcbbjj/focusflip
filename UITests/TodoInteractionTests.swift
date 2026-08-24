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

        // --- 右滑删除「读书」（非当前任务，标题唯一） ---
        let reading = app.staticTexts["读书"]
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        reading.swipeLeft()
        let deleteBtn = app.buttons["删除"].firstMatch
        var diag = ""
        if deleteBtn.waitForExistence(timeout: 2) {
            diag += "swipe后露出删除按钮;"
            deleteBtn.tap()
            // 判别假设：行的 tap 手势抢走删除按钮点击 → 误开编辑页
            let editSheet = app.navigationBars["编辑任务"]
            if editSheet.waitForExistence(timeout: 2) {
                XCTFail("点「删除」误开编辑页 —— 行 onTapGesture 吃掉了 swipe 按钮点击")
                app.buttons["关闭"].firstMatch.tap()
                return
            }
        } else {
            diag += "swipe后未露出删除按钮,试全扫;"
            let start = reading.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            let end = reading.coordinate(withNormalizedOffset: CGVector(dx: -0.3, dy: 0.5))
            start.press(forDuration: 0.02, thenDragTo: end,
                        withVelocity: .fast, thenHoldForDuration: 0.1)
            if deleteBtn.waitForExistence(timeout: 2) {
                diag += "全扫后露出,点按;"
                deleteBtn.tap()
            } else {
                diag += "全扫后仍未露出;"
            }
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "after-delete-attempt"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(app.state, .runningForeground, "右滑删除后 app 存活")
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: reading)
        let waitResult = XCTWaiter().wait(for: [gone], timeout: 5)
        XCTAssertEqual(waitResult, .completed, "「读书」删除后应消失（\(diag)）")

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

        // --- 卡片快捷开始（▶︎）---
        let play = app.buttons["开始这个任务"].firstMatch
        if play.waitForExistence(timeout: 3) {
            play.tap()
            XCTAssertEqual(app.state, .runningForeground, "快捷开始后 app 存活")
            let focusTab = app.tabBars.buttons["专注"]
            XCTAssertTrue(focusTab.waitForExistence(timeout: 5))
            focusTab.tap()   // 回任务页继续
            _ = app.staticTexts["写代码"].waitForExistence(timeout: 5)
        }

        // --- 添加任务 ---
        let add = app.buttons["todo.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "未找到 + 按钮")
        add.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "添加页输入框未出现")
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
