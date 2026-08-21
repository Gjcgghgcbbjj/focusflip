# FocusFlip 交接文档（给下一个 AI / 开发者）

> 最后更新：2026-08-21
> 仓库：https://github.com/Gjcgghgcbbjj/focusflip （公开）
> 构建方式：GitHub Actions（macos-15 + 动态选择 Xcode + xcodegen，双 target）

---

## 一、项目现状（v3.1.0 — 个人自用体验包）

**v3.1.0 新增（定位：个人自用，不做留存类功能）：**
- 屏幕常亮：专注运行时 isIdleTimerDisabled（设置-行为可关）
- 沉浸模式：专注时 ImmersiveFocusView 全屏覆盖 TabView，暂停即退出
- +5 分钟延长：engine.extendCurrentPhase(by:)，墙钟派生，通知/灵动岛同步
- Siri 快捷指令：Sources/App/FocusFlipIntents.swift（AppIntents，iOS16+；注意协议属性名是 appShortcuts 且每条 phrase 必须含 \(.applicationName)；CI 里 appintentsnltrainingprocessor 的 SSU 报错非致命）
- 自动备份：进后台 autoBackupIfNeeded() 滚动 7 天到 Documents/FocusFlipBackups；设置页可一键「备份到文件 App」（DocumentExporter → iCloud Drive）
- 任务时间分布卡：StatsModel3.taskStats 按 taskId 聚合 Top6
- 任务筛选（全部/进行中/已完成）+ 编辑模式拖拽排序（sortOrder 持久化）

**v3.0.0 "Calm Focus" — 应用户要求彻底从零重写全部 UI**

设计哲学：
- 纯黑/纯白底，唯一强调色 = 用户主题色
- 大留白、元素少而精、数字是主角（SF Pro Rounded 超细体）
- 动效克制：只在状态切换时有意义地动

### 文件结构（新）

| 文件 | 说明 |
|------|------|
| `Sources/Theme/DesignSystem3.swift` | DS3 设计系统：S 间距/R 圆角/Color/Font/Anim token + UIColorToken（UIAppearance 用）+ hex init（全项目唯一定义处） |
| `Sources/Features/Timer/TimerView3.swift` | 计时页：全屏大圆环（线宽随尺寸自适应）、环内超大 thin 数字与环同一时间源、暂停呼吸动画、今日进度条、任务 chip、三按钮控制区 |
| `Sources/Features/Stats/StatsView3.swift` | 统计页：StatsModel3（@MainActor 数据层）+ StatsModern3（iOS16 Charts）+ StatsFallback3（iOS15 胶囊柱）。日时段/近7天/近30天柱图、月历热力图（周一起始5级色阶）、hero 卡、2x2 磁贴、会话分布 |
| `Sources/Features/Tasks/TasksView3.swift` | 任务页：List 行卡片化、左滑完成/右滑删除、TaskEditSheet3（名称/备注/预估/8色板）、空状态引导 |
| `Sources/Features/Settings/SettingsView3.swift` | 设置页：预设四方案（结构化激活判断）/时长/目标/声音+试听/行为/6色主题/App屏蔽选择器/数据导入导出清除/关于。含 ShareSheet |

已删除：旧 TimerView / StatsView / StatsLegacyView / SettingsView / TasksView / DesignSystem(v2) / Compatibility / FlipClock 全家。

### 引擎层（v2 沿用，多轮修复后稳定）

- `PomodoroEngine`：墙钟派生剩余时间（phaseStartDate 为源），暂停精确冻结；skip/reset 记录实际时长；recordSession 传真实 startDate
- `TimerService`：DispatchSourceTimer + 静音音频保活。**stop() 同时停静音音频但保留 AVAudioSession**（白噪音可继续）；deactivateBackground() 才释放会话；reset() 走完整释放
- `NotificationService`：区分短休/长休文案，专注完成通知带任务名
- `PersistenceController`：程序化 CoreData 模型 + App Group 共享；import/clear 后自动 WidgetCenter.reloadAllTimelines()
- `HapticManager`：5 个 generator 复用 + prepare（属性名 selectionGen 避免与方法冲突）
- URL scheme：focusflip://start|pause|resume|skip|reset|timer|tasks|stats|settings；start 自动切 tab + 白噪音

### 已知限制

- **App 屏蔽**依赖 TrollStore 私有权限，真机可能不生效（代码逻辑正确，entitlements 不能编造否则闪退）
- Widget 扩展不能引用 Sources/ 下任何东西（DS3 不可见），Widget/ 内用字面量
- 不要使用 widgetContainerBackground/containerBackground —— 曾致编译失败
- 图表 x 轴类目标签必须唯一（空字符串会合并类目），密度用 desiredCount 控制
- iOS16+ API 注意：fontWeight(17+) 等需 gate 或替代写法

### 版本/发布流程

- 版本三处同步：project.yml MARKETING_VERSION + FocusFlip.plist（版本+build）+ workflow APP_VERSION
- 发布：commit → tag vX.Y.Z → push tag → CI 自动 build + release
- 下载 URL：`https://github.com/Gjcgghgcbbjj/focusflip/releases/download/vX.Y.Z/FocusFlip-X.Y.Z.ipa`
- 当前：v3.1.0 (build 8)

### 待真机验证

- 新计时页圆环渲染/暂停呼吸动画
- 统计图表数据正确性
- Widget/Live Activity 显示
- App 屏蔽实际效果
