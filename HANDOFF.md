# FocusFlip 交接文档（给下一个 AI / 开发者）

> 最后更新：2026-08-18
> 仓库：https://github.com/Gjcgghgcbbjj/focusflip （公开）
> 构建方式：GitHub Actions（macos-15 + 动态选择 Xcode + xcodegen，双 target）

---

## 一、项目现状（v1.1.0）

**已完成：**
- ✅ SwiftUI 番茄钟 App（26 个 Swift 文件，~3600 行）
- ✅ 自适应主题：Catppuccin **Mocha（暗色）+ Latte（亮色）** 随系统切换
- ✅ 番茄计时引擎 + 后台保活（静音音频 + DispatchSourceTimer）+ Live Activity 推送
- ✅ 主屏今日卡（今日番茄/分钟/每日目标进度条）+ 目标达成庆祝动画 + `.finished` 状态
- ✅ 每日目标（设置可调 1-24）+ 完成后状态机（onAllComplete 真实触发）
- ✅ 统计页日/周/月切换 + 24h 分段图 + 30 天图 + **当月日历热力图** + 连续天数 streak
- ✅ `focusflip://` 快捷指令（start/pause/resume/skip/reset/tasks/stats/settings）+ tab 路由
- ✅ **真实 WAV 音频**（雨/海/森林/风扇 10-16s 无缝循环 + 4 种完成音，Python 离线合成）
- ✅ **锁屏小组件 + Live Activity**：独立 Widget Extension target + App Group 共享 CoreData
- ✅ 备份到文件 App：导出/导入（按 id 去重 upsert）/清除数据（二次确认）
- ✅ iOS 15 统计降级页（无 Charts 依赖）
- ✅ 技术债清理：@StateObject 单例反模式 → @ObservedObject
- ✅ 闪退三大根因修复：Info.plist 覆盖 / 编造 entitlements / 图标缺失
- ✅ CI 冒烟测试（模拟器真启动 + 进程存活）全绿

**IPA 状态：**
- ✅ v1.1.0 Release：`https://github.com/Gjcgghgcbbjj/focusflip/releases/download/v1.1.0/FocusFlip-1.1.0.ipa`（~5MB）
- ✅ 已含 Widget 扩展（PlugIns/FocusFlipWidgetExtension.appex）+ 8 个 WAV + 无签名（TrollStore 安装时签名）
- ⚠️ 真机已验证能打开不闪退（v1.0.1）；**1.1.0 新功能待真机验收**
- ❌ 旧 v1.0.0 本地 IPA 已删除（含编造 entitlements）

---

## 二、关键架构

```
Sources/
├── App/FocusFlipApp.swift        # @main + TabView(路由) + onOpenURL + UIAppearance
├── Theme/DesignSystem.swift      # Mocha+Latte 双调色板，动态 UIColor token
│        Compatibility.swift      # iOS 15/16 兼容（numericTextTransition 等）
├── Engine/                       # PomodoroEngine 状态机 + TimerService 保活 + 通知
├── Features/                     # Timer（今日卡/庆祝）/Tasks/Stats(+Legacy)/Settings/Sound/FlipClock
├── FocusShield/                  # App 屏蔽（私有 API，待真机验证）
└── Models/AppSettings.swift      # 设置（含 dailyGoalPomodoros）
Shared/                           # 主 App 与 Widget 扩展【双 target 共用】
├── PersistenceController.swift   # CoreData（App Group 容器 + 旧库自动迁移 + JSON 导入导出/清除）
├── FocusSession.swift            # 会话模型 + SessionType
├── TaskItem.swift                # 任务模型
└── LiveActivityAttributes.swift  # ActivityKit 属性 + LiveActivityManager（phaseEndDate 驱动）
Widget/                           # 仅编译进 Widget 扩展 target
├── FocusFlipWidget.swift         # 锁屏小组件（今日专注）
├── FocusFlipWidgetBundle.swift   # @main WidgetBundle
├── LockScreenWidget.swift        # Live Activity 渲染（TimelineView 自走倒计时）
└── Info.plist                    # NSExtensionPointIdentifier=com.apple.widgetkit-extension
```

### 双 target
1. **FocusFlip**（主 App，iOS 15.0+，embed Widget 扩展）
2. **FocusFlipWidgetExtension**（app-extension，iOS 16.0+，Widget + Live Activity 渲染）

### 数据共享
- App Group `group.com.focusflip.app`，CoreData 库在共享容器
- 旧版（Application Support）数据首次启动自动迁移到共享容器

---

## 三、构建系统

### GitHub Actions（推荐，已验证）
- macos-15 runner，**动态选择 Xcode**（见教训）
- `xcodegen generate` → `xcodebuild archive`（免签名）→ package-ipa.sh 打 zip（不预签名）
- tag `v*` 自动创建 Release（需 workflow 里 `permissions: contents: write`）
- 产物：Artifacts `FocusFlip-<版本>-ipa` + Release asset + 模拟器截图

### 手动重建
```bash
xcodegen generate
xcodebuild archive -project FocusFlip.xcodeproj -scheme FocusFlip -configuration Release \
  -destination "generic/platform=iOS" -archivePath build/FocusFlip.xcarchive \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
APP_VERSION=1.1.0 ./Scripts/package-ipa.sh build/FocusFlip.xcarchive
```

### ⚠️ 关键教训（必须记住）
- **不要用 xcodegen 的 `info: path:` 块** —— 会生成空 Info.plist 覆盖手写 plist → 闪退。
  正确：`INFOPLIST_FILE` + `GENERATE_INFOPLIST_FILE: NO`
- **不要预签名 / 不要塞编造 entitlements** —— TrollStore 安装时自行注入 platform-application。
  只保留合法键：ActivityKit + application-groups
- **Xcode 版本不能写死** —— "Select Xcode" 步骤用 actool 探测自动选（当前镜像命中 Xcode 26.3）。
  Xcode 16.x 无匹配模拟器运行时会导致 actool 报 "No simulator runtime version..."
- **Widget 相关背景 API 在 Xcode 26 下不稳定** —— 不要用 `widgetContainerBackground()` /
  `containerBackground(for: .widget)`（主 target 报 `ContainerBackgroundPlacement.widget` 无法解析）。
  小组件背景交给系统自动渲染即可
- **不要写 `APPLICATION_EXTENSION_API_ONLY: YES`** 到 widget 扩展 target（疑似引发上述解析问题）
- 版本号集中：project.yml 的 MARKETING_VERSION + FocusFlip.plist + workflow 的 APP_VERSION
  （package-ipa.sh 从环境变量读 APP_VERSION）
- 共享代码改动后必须**双 target 都验证**（CI 的 archive 会同时编）

---

## 四、待办 / 已知问题

### 优先级高
1. **App 屏蔽真机验证** —— `FocusShieldManager` 用私有 API
   （`setApplicationHidden:forBundleIdentifier:`），依赖 TrollStore 注入的 platform-application。
   若失效需谨慎补真实 entitlement（只加验证过的合法键）
2. **Widget/Live Activity 真机验证** —— TrollStore 下 Widget 有先例（EeveeSpotify）可行；
   **动态岛/Live Activity 在 TrollStore 下有已知失效风险**（社区多个案例），真机确认

### 优先级中
3. 统计页热力图只有当月，可扩展为可翻月
4. 白噪音音质仍有提升空间（换专业录音素材）
5. 任务 tab 与今日卡数据联动（导入后需刷新）

### 已知限制
- iOS 15 无真实 Charts（降级页为简化版）
- Live Activity 需要 iOS 16.2+

---

## 五、验证清单

- [x] CI：编译（双 target）+ 模拟器冒烟测试（启动存活）
- [x] v1.0.1 真机打开不闪退
- [ ] 1.1.0 真机：今日卡/每日目标达成庆祝/深浅色切换/统计热力图/快捷指令/白噪音新音质
- [ ] 1.1.0 真机：锁屏小组件是否出现（TrollStore）
- [ ] 1.1.0 真机：Live Activity 是否显示（TrollStore，风险项）
- [ ] 备份导出→导入→数据还原
- [ ] App 屏蔽

---

## 六、环境信息

| 项 | 值 |
|----|-----|
| 仓库 | https://github.com/Gjcgghgcbbjj/focusflip |
| 最新 Release | v1.1.0（`FocusFlip-1.1.0.ipa`，~5MB） |
| 本地路径 | `/root/dsphn/focusflip/` |
| 最低系统 | iOS 15.0（Widget 扩展 16.0+） |
| Bundle ID | com.focusflip.app（扩展 com.focusflip.app.widget） |
| App Group | group.com.focusflip.app |
| 安装方式 | TrollStore（巨魔） |
| 构建 Xcode | 动态选择（当前镜像命中 Xcode 26.3.0） |

---

## 七、给下一个 AI 的建议

1. 任何改动 → push master → 等 CI 全绿 → 打 tag `vX.Y.Z` 自动发 Release
2. 改 Shared/ 或 project.yml 后必须确认双 target 编译通过（CI archive 步骤覆盖）
3. 用户优先验收：小组件/Live Activity/App 屏蔽三个真机项
4. 若 Live Activity 在 TrollStore 真机失效：保留代码，标注限制，不投入修复
5. 若 App 屏蔽失效：只补 `com.apple.frontboard.launchapplications` 等真实存在的键并真机验证，
   严禁再引入编造键
