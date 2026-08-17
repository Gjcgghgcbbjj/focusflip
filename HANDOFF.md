# FocusFlip 交接文档（给下一个 AI / 开发者）

> 最后更新：2026-08-18
> 仓库：https://github.com/Gjcgghgcbbjj/focusflip （公开）
> 构建方式：GitHub Actions（macos-15 + Xcode 16 + xcodegen）

---

## 一、项目现状

**已完成：**
- ✅ SwiftUI 番茄钟 App 完整源码（25 个 Swift 文件，~3200 行）
- ✅ Catppuccin Mocha 设计系统（`Sources/Theme/DesignSystem.swift`）
- ✅ 番茄计时引擎 + 后台保活（静音音频 + DispatchSourceTimer）
- ✅ 任务管理、统计图表、白噪音合成、Live Activity/Widget、App 屏蔽（TrollStore 提权）
- ✅ GitHub Actions 自动化构建 IPA
- ✅ **最近修复了闪退根因**：Info.plist 关键键曾被 xcodegen 覆盖清空，现已修复

**IPA 状态：**
- ✅ `build/fixed/FocusFlip-1.0.0.ipa`（212KB）已在 GitHub Actions 成功构建
- ✅ 已验证 Info.plist 包含全部关键键（UILaunchScreen / UIBackgroundModes / NSSupportsLiveActivities）
- ✅ 已复制到 Windows 桌面 `C:\Users\niting\Desktop\FocusFlip-1.0.0.ipa`
- ⚠️ **尚未在真机验证**：用户需要安装测试，确认不再闪退

---

## 二、关键架构

```
Sources/
├── Theme/
│   ├── DesignSystem.swift      # 设计 token（颜色/间距/圆角/字体/动画）
│   └── Compatibility.swift     # iOS 15 兼容层（contentTransition 等降级）
├── App/FocusFlipApp.swift      # @main + TabView + UIAppearance
├── Models/                     # CoreData（程序化模型，无 xcdatamodeld）
│   ├── FocusSession.swift      # 会话记录
│   ├── TaskItem.swift          # 任务
│   ├── AppSettings.swift       # UserDefaults 设置
│   └── PersistenceController.swift  # CoreData 栈 + JSON 导出
├── Engine/
│   ├── PomodoroEngine.swift    # 状态机（专注/短休/长休循环）
│   ├── TimerService.swift      # 后台计时（静音保活）
│   └── NotificationService.swift # 本地通知
├── Features/
│   ├── FlipClock/              # 简约数字显示（旧 3D 翻页已弃用）
│   ├── Timer/TimerView.swift   # 主计时屏
│   ├── Tasks/TasksView.swift   # 任务卡片列表
│   ├── Stats/StatsView.swift   # Charts 统计
│   ├── Sound/SoundPlayer.swift # AVAudioEngine 白噪音合成
│   └── Settings/SettingsView.swift
├── FocusShield/FocusShieldManager.swift  # App 屏蔽（私有 API）
└── Utils/                      # Haptics + DateUtils
Widget/                         # Live Activity + Widget（编入主 binary）
```

---

## 三、构建系统

### 双路径
1. **GitHub Actions（推荐，已验证）**：`.github/workflows/build-ipa.yml`
   - macos-15 runner + Xcode 16
   - `brew install xcodegen` → `xcodegen generate` → `xcodebuild archive`（免签名）→ ldid 打包
   - 触发：push 到 master 或打 tag `v*`
   - 产物：Actions Artifacts（`FocusFlip-1.0.0-ipa`）

2. **本地 theos**：`Makefile`（未验证，环境无 Swift 编译器，不推荐）

### ⚠️ 关键教训（必须记住）
- **不要用 xcodegen 的 `info: path:` 块** —— 它会重新生成空 Info.plist，
  覆盖手写的 `FocusFlip.plist`，导致 UILaunchScreen 等键丢失 → **App 闪退**
- 正确做法：`settings.base` 里设 `INFOPLIST_FILE: FocusFlip.plist` + `GENERATE_INFOPLIST_FILE: NO`
- Widget 文件编入主 binary 时 **不能有 `@main`**（会和 App 的 `@main` 冲突）

### 手动重建命令
```bash
# 1. 本地生成 Xcode 工程
brew install xcodegen
xcodegen generate

# 2. 无签名构建
xcodebuild archive \
  -project FocusFlip.xcodeproj \
  -scheme FocusFlip -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/FocusFlip.xcarchive \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. ldid 打包（TrollStore 会自行重签名）
./Scripts/package-ipa.sh build/FocusFlip.xcarchive
```

---

## 四、待办 / 已知问题

### 优先级高
1. **真机验证闪退修复** —— 用户需安装 `build/fixed/FocusFlip-1.0.0.ipa` 测试
2. **App 图标** —— 目前是空占位（`Resources/Assets.xcassets/AppIcon.appiconset` 无 1024px 图），需要生成图标
3. **App 屏蔽功能验证** —— `FocusShieldManager` 用私有 API（`setApplicationHidden:forBundleIdentifier:`），
   依赖 TrollStore 的 platform-application 提权，真机未验证

### 优先级中
4. **@StateObject 单例反模式** —— `TimerView` 等用 `@StateObject` 包 `PomodoroEngine.shared`，
   严格应改 `@ObservedObject`（目前能编译能跑）
5. **Widget 是死代码** —— 编入主 binary 但无 `@main` WidgetBundle，锁屏小组件实际不生效。
   若要真正支持 Widget，需拆分成独立 Widget Extension target（xcodegen 支持多 target）
6. **`onAllComplete` 回调未使用** —— `PomodoroEngine` 里声明了但从未触发 `.finished` 状态

### 优先级低
7. 白噪音合成音质（雨声/海浪）较粗糙，可换真实音频文件
8. 统计页 Charts 在 iOS 15 上不可用（已用 `@available(iOS 16.0, *)` 降级隐藏 tab）

---

## 五、验证清单（用户验收前必须确认）

- [ ] 安装 IPA 后 App 能正常启动（不闪退）
- [ ] 点击开始 → 计时器倒数
- [ ] 专注结束 → 通知 + 提示音
- [ ] 任务创建/编辑/删除
- [ ] 统计页显示数据
- [ ] 白噪音开关
- [ ] 设置页时长修改生效
- [ ] （可选）App 屏蔽功能

---

## 六、环境信息

| 项 | 值 |
|----|-----|
| 仓库 | https://github.com/Gjcgghgcbbjj/focusflip |
| GitHub 账号 | Gjcgghgcbbjj |
| Windows 桌面 | `C:\Users\niting\Desktop\` |
| 最新 IPA | `build/fixed/FocusFlip-1.0.0.ipa`（212KB） |
| 本地路径 | `/root/dsphn/focusflip/` |
| 最低系统 | iOS 15.0 |
| Bundle ID | com.focusflip.app |
| 安装方式 | TrollStore（巨魔） |

---

## 七、给下一个 AI 的建议

1. **先让用户安装测试** `build/fixed/FocusFlip-1.0.0.ipa`，确认不闪退再继续开发
2. 如果用户要 **App 图标**：生成 1024×1024 图标放入 `Resources/Assets.xcassets/AppIcon.appiconset/`，
   命名 `icon_1024.png` 并更新 Contents.json
3. 如果要 **真正的锁屏 Widget**：用 xcodegen 加 `FocusFlipWidgetExtension` target
4. 每次改完源码 → push 到 master → 等 Actions 构建 → 下载 IPA → 复制到桌面
5. 修改 `project.yml` 后必须验证 Info.plist 关键键仍在（用上面 python 脚本检查）
