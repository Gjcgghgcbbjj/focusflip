# FocusFlip 交接文档（给下一个 AI / 开发者）

> 最后更新：2026-08-18
> 仓库：https://github.com/Gjcgghgcbbjj/focusflip （公开）
> 构建方式：GitHub Actions（macos-15 + 动态选择 Xcode + xcodegen，双 target）

---

## 一、项目现状（v2.0.0）

**v2.0.0 — 全量 UI 重写，对标 Be Focused / Focus Keeper / Flow**

已完成：
- ✅ 全新设计体系（DesignSystem v2.0）：近黑底 + 语义阶段色 + 自适应深浅色
- ✅ 全新计时界面：沉浸式大圆环 + 轮次进度圆点 + TimelineView 平滑动画
- ✅ 全新统计界面：今日大卡 + 日/周/月柱状图 + 月热力图 + 总览网格 + bestStreak
- ✅ 全新设置界面：预设方案卡片 + StepperRow/ToggleRow 复用 + Shield 选择器
- ✅ 全新任务界面：清单卡片 + 左色条 + 进度条 + 空状态
- ✅ Widget + Live Activity 重写：Dynamic Island 全区域 Text(timerInterval) 自走倒计时
- ✅ 核心逻辑修复：跳过记录实际时长 / 通知调度 / streak 从昨天算 / Widget 5min 刷新
- ✅ CI 全绿（编译 + 模拟器冒烟测试）
- ✅ v2.0.0 Release 自动发布

**IPA 状态：**
- ✅ v2.0.0 Release：`FocusFlip-2.0.0.ipa`（~5MB）
- ✅ 含 Widget 扩展 + 8 个 WAV + 无签名（TrollStore 安装时签名）
- ✅ 数据兼容 v1.x（CoreData 模型未变）

**待真机验收：**
- Widget / Live Activity / App 屏蔽

---

## 二、关键架构

```
Sources/
├── App/FocusFlipApp.swift        # @main + TabView + onOpenURL + UIAppearance
├── Theme/
│   ├── DesignSystem.swift        # v2.0 颜色/字体/间距/动画/PhaseTheme/View修饰符
│   └── Compatibility.swift       # iOS 15/16 兼容（已清理，方法移入 DesignSystem）
├── Engine/                       # PomodoroEngine + TimerService + NotificationService
├── Features/                     # Timer/Stats/StatsLegacy/Settings/Tasks/Sound/FlipClock
├── FocusShield/                  # App 屏蔽（私有 API，已崩溃安全）
└── Models/AppSettings.swift
Shared/                           # 主 App 与 Widget 扩展【双 target 共用】
├── PersistenceController.swift   # CoreData（App Group + JSON 导入导出/清除）
├── FocusSession.swift / TaskItem.swift
└── LiveActivityAttributes.swift  # ActivityKit + LiveActivityManager
Widget/                           # 仅编译进 Widget 扩展 target
├── FocusFlipWidget.swift         # 锁屏小组件（注意：不能用 DS.*，扩展看不到）
├── FocusFlipWidgetBundle.swift
├── LockScreenWidget.swift        # Live Activity（注意：不能用 DS.*）
└── Info.plist
```

### ⚠️ 关键教训
- **Widget 扩展 target 看不到 `Sources/` 里的 DS/DesignSystem** —— Widget 代码里用字面量（如 spacing: 8），不能用 DS.S.sm
- **不要用 `widgetContainerBackground()` / `containerBackground(for: .widget)`** —— Xcode 26 下报 ContainerBackgroundPlacement.widget 无法解析；系统自动渲染背景
- **不要写死 Xcode 版本** —— 用 actool 动态选择
- **不要预签名 / 不要塞编造 entitlements** —— TrollStore 安装时自行注入
- **`Compatibility.swift` 和 `DesignSystem.swift` 不要重复定义同名方法** —— 会编译报错

---

## 三、环境信息

| 项 | 值 |
|----|-----|
| 仓库 | https://github.com/Gjcgghgcbbjj/focusflip |
| 最新 Release | v2.0.0 |
| 最低系统 | iOS 15.0（Widget 扩展 16.0+，Live Activity 16.2+） |
| 安装方式 | TrollStore（巨魔） |
