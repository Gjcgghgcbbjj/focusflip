# 🍅 FocusFlip

> iOS 番茄钟 App · 支持巨魔商店(TrollStore)自签 · 翻页时钟 · Live Activity · App 屏蔽

原生 SwiftUI 构建，iOS 15.0+，通过 TrollStore 安装获得平台应用权限，支持专注期间屏蔽干扰 App。

---

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| 🍅 **专注/休息循环** | 经典番茄工作法：25分钟专注 + 5分钟休息，4个后长休息 |
| ⏱️ **自定义时长** | 自由设置专注/休息时长、循环次数，支持快速预设 |
| 📋 **任务管理** | 创建任务、预估番茄数、卡片化展示、颜色标记 |
| 📊 **数据统计** | 今日/本周专注时间、7天趋势图、连续打卡天数 |
| 🎨 **设计系统** | Catppuccin Mocha 配色，SF Pro Rounded 字体，4pt 间距网格 |
| 🎵 **白噪音** | 雨声/海浪/森林/风扇，运行时合成无需音频文件 |
| 📱 **Live Activity** | iOS 16.1+ 锁屏实时显示倒计时 + 灵动岛交互 |
| 🛡️ **App 屏蔽** | 专注期间隐藏选定 App（需 TrollStore 提权） |
| 💾 **本地持久化** | CoreData 存储，支持 JSON 导出 |

## 📸 界面预览

```
┌─────────────────────────────┐
│  🧠 专注                     │  ← 阶段标签 + 图标
│  第 1 轮 · 0 番茄        🔊  │
│                             │
│         ╭─────────╮         │
│        ╱           ╲        │  ← 进度环 (6pt, 语义色)
│       │             │       │
│       │   24:53     │       │  ← SF Pro Rounded ultraLight
│       │   专注中     │       │
│        ╲           ╱        │
│         ╰─────────╯         │
│                             │
│      ● 写论文  2/4          │  ← 任务 chip
│                             │
│    ↻      ▶      ⏭         │  ← 控制按钮
└─────────────────────────────┘

背景: #1e1e2e (Catppuccin Mocha)
专注色: #f38ba8  短休色: #a6e3a1  长休色: #89b4fa
```

## 🏗️ 架构设计

```
focusflip/
├── Makefile                          # theos 构建配置
├── control                           # deb 元信息
├── FocusFlip.plist                   # Info.plist（权限、URL Scheme）
├── FocusFlip.entitlements            # TrollStore 提权 entitlements
├── Sources/
│   ├── Theme/
│   │   └── DesignSystem.swift        # 设计 token（配色/间距/字体/动画）
│   ├── App/
│   │   └── FocusFlipApp.swift        # @main 入口 + TabView
│   ├── Models/
│   │   ├── FocusSession.swift        # 专注会话 CoreData 模型
│   │   ├── TaskItem.swift           # 任务 CoreData 模型
│   │   ├── AppSettings.swift        # UserDefaults 设置中心
│   │   └── PersistenceController.swift # CoreData 栈 + JSON 导出
│   ├── Engine/
│   │   ├── PomodoroEngine.swift     # 计时状态机
│   │   ├── TimerService.swift       # 后台计时（DispatchSourceTimer + 静音保活）
│   │   └── NotificationService.swift # 本地通知
│   ├── Features/
│   │   ├── FlipClock/
│   │   │   ├── FlipClockView.swift   # 简约数字显示
│   │   │   ├── FlipDigitView.swift  # 单数字过渡
│   │   │   └── FlipTransition.swift # 过渡修饰器
│   │   ├── Timer/TimerView.swift    # 计时主屏
│   │   ├── Tasks/TasksView.swift    # 任务卡片列表
│   │   ├── Stats/StatsView.swift    # 统计图表
│   │   ├── Sound/SoundPlayer.swift  # 白噪音 + 提醒音合成
│   │   └── Settings/SettingsView.swift # 设置页
│   ├── FocusShield/
│   │   └── FocusShieldManager.swift # App 屏蔽（LSApplicationWorkspace）
│   └── Utils/
│       ├── HapticManager.swift      # 触感反馈
│       └── DateUtils.swift          # 日期工具
├── Widget/
│   ├── FocusFlipWidget.swift        # 锁屏小组件
│   ├── LockScreenWidget.swift       # Live Activity + 灵动岛
│   └── LiveActivityAttributes.swift # ActivityKit 属性定义
├── Resources/
│   ├── Assets.xcassets/             # 图标资源
│   └── Sounds/                      # 音频资源（运行时合成，通常为空）
└── Scripts/
    ├── build-ipa.sh                 # 一键构建 IPA
    └── install-trollstore.md        # 安装指南
```

### 核心模块说明

#### 🔄 PomodoroEngine（计时引擎）

状态机驱动，管理完整的番茄工作法循环：

```
idle → focusing → shortBreak → focusing → ... → longBreak → focusReady
                    ↓ pause                          ↓ pause
                 paused                           paused
                    ↓ resume                        ↓ resume
                 shortBreak                        longBreak
```

- 发布 `@Published` 属性，SwiftUI 视图自动响应
- 通过 `TimerService` 获取 1 秒 tick
- 完成时自动记录到 CoreData

#### ⏱️ TimerService（后台计时）

```
┌──────────────────────────────────────────┐
│  DispatchSourceTimer (1s tick)            │
│         ↓                                 │
│  AVAudioSession (.playback)               │
│         ↓                                 │
│  Silent Audio Loop (1s WAV, volume=0.01)  │  ← 防止后台被挂起
│         ↓                                 │
│  PomodoroEngine.handleTick()              │
└──────────────────────────────────────────┘
```

iOS 后台保活策略：播放近乎静音的音频循环，使系统认为 App 在播放音频，从而保持后台运行。

#### 🎴 FlipDigitView（翻页时钟）

每个数字位由 4 层视图组成：
1. **底部静态卡** — 新数字的下半部分
2. **顶部静态卡** — 旧数字的上半部分
3. **翻转上卡** — 旧数字下半部分翻转（rotation3D 0→90°）
4. **翻转下卡** — 新数字上半部分翻转（rotation3D -90→0°）

通过 `rotation3DEffect` + `perspective` 实现 3D 翻牌效果。

#### 🛡️ FocusShieldManager（App 屏蔽）

```
TrollStore 安装 → platform-application entitlement
         ↓
LSApplicationWorkspace (私有框架 FrontBoard)
         ↓
setApplicationHidden:forBundleIdentifier:
         ↓
专注期间隐藏选定 App，休息时恢复
```

使用 NSClassFromString + perform selector 调用私有 API，避免编译时依赖。

#### 🎵 SoundPlayer（音频合成）

白噪音和提醒音均在运行时用 AVAudioEngine 合成，**无需打包音频文件**：

| 类型 | 合成方式 |
|------|---------|
| 雨声 | 白噪声 + 高通滤波 |
| 海浪 | 棕噪声 + 低频 LFO |
| 森林 | 滤波噪声 + 随机鸟鸣正弦波 |
| 风扇 | 棕噪声（低通） |
| 提醒音 | 多频率正弦波 + 包络 |

## 🚀 快速开始

### 构建环境准备

```bash
# 1. 安装 theos
git clone --recursive https://github.com/theos/theos.git /opt/theos
export THEOS=/opt/theos

# 2. 安装 ldid
# macOS:
brew install ldid
# Linux:
# 见 https://github.com/ProcursusTeam/ldid

# 3. 下载 iOS SDK
git clone https://github.com/theos/sdks.git $THEOS/sdks
```

### 构建并安装

```bash
# 构建 IPA
cd focusflip
chmod +x Scripts/build-ipa.sh
./Scripts/build-ipa.sh

# 产物: build/FocusFlip-1.0.0.ipa
```

详细的安装步骤见 [Scripts/install-trollstore.md](Scripts/install-trollstore.md)。

## 📱 系统要求

| 特性 | 最低版本 |
|------|---------|
| 基本功能 | iOS 15.0+ |
| Live Activity | iOS 16.1+ |
| 灵动岛交互 | iOS 16.1+ (iPhone 14 Pro+) |
| App 屏蔽 | TrollStore 安装（iOS 15.0-17.0） |
| 锁屏小组件 | iOS 16.0+ |

## 🛠️ 技术栈

- **UI 框架**：SwiftUI
- **数据持久化**：CoreData（程序化模型，无 .xcdatamodeld）
- **后台保活**：AVAudioSession + DispatchSourceTimer
- **音频合成**：AVAudioEngine
- **Live Activity**：ActivityKit
- **小组件**：WidgetKit
- **图表**：Charts framework
- **构建工具**：theos
- **签名**：ldid (fake-sign) + TrollStore (platform re-sign)
- **App 屏蔽**：LSApplicationWorkspace (FrontBoard 私有框架)

## 📄 许可证

MIT License — 自由使用、修改、分发。

## 🤝 贡献

欢迎提交 Issue 和 PR。
