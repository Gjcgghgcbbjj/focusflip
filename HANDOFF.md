# FocusFlip — 交接文档

> **2026-08-21 重生**：旧产品代码全部废弃，封存于 `archive/focusflip-v3` 分支。
> 当前 master 为全新起点 —— **完全模拟 Flow（极简番茄钟）的核心体验**。

## 当前形态：Flow-Sim v1.0.0 (build 1)

### 设计三要素（照搬 Flow）
1. **色即界面**：选中任务的颜色铺满整屏（上浅下深渐变），阶段切换颜色平滑过渡
   - 未选任务 → 靛蓝 `#5865F2`；小憩 → 绿 `#2FA84F`；长歇 → 蓝 `#1E88C7`
2. **大圆环细字**：280pt 圆环 + 56pt 圆体时间，点环暂停/继续
3. **时长快选 chips**：`15/20/25/30/45/50/60` + `···` 精调面板（步进器）

### 流程
专注 → 完成 → prepared(小憩/长歇，按完成番茄数 % longEvery 触发长歇) → 循环。
自动开始两个开关在设置页。跳过记录中断会话；放弃有确认弹窗。

### 文件地图（全部新代码）
```
Sources/App/FlowSimApp.swift      入口 + TabView(计时/设置) tint #5865F2
Sources/Core/Theme.swift          Palette(场景渐变/深变体/任务色板) + Layout
Sources/Core/Prefs.swift          UserDefaults 偏好(自动开始×2/常亮/时长×4)
Sources/Core/Engine.swift         墙钟状态机 idle/running/paused/prepared
Sources/Core/Store.swift          CoreData 程序化模型(TaskEntity/SessionEntity)
                                  独立存储 ApplicationSupport/FlowSim/FlowSim.sqlite
Sources/Core/Services.swift       KeepAlive(静音WAV保活+1s tick) + Notifications
Sources/Features/HomeView.swift   主屏：任务头/圆环/chips/主按钮/放弃跳过
Sources/Features/Sheets.swift     TaskPickerSheet + DurationTuneSheet
Sources/Features/SettingsView.swift 行为/时长/概览/关于
```

### 关键实现约定
- **墙钟派生**：startedAt+totalSeconds 是唯一真相源；暂停=冻结 remaining 并置 startedAt=nil；恢复=totalSeconds=冻结值、startedAt=now
- KeepAlive tick 经静态 PassthroughSubject 广播，引擎订阅驱动 handleTick
- 通知权限只在首次询问时写结果（`notifAsked` 标记），永不覆盖用户开关
- iOS15 兼容红线：无 contentTransition/fontWeight(View)/NavigationStack
- CoreData fetchRequest 必须显式类型化（程序化模型无 codegen）

### 工程精简
单 target；已移除 Widget 扩展 / LiveActivity / AppGroup / AppIntents / Charts。
保留：TrollStore 签名链路、GitHub Actions(tag→IPA)、Sounds 资源(未来白噪音用)、AppIcon。

## 版本线
- v1.0.0 (build 1)：重生首版 — Flow 核心体验
- 归档：`archive/focusflip-v3` 分支 + GitHub Releases v3.x 历史（未删）

## 下一步路线（按优先级）
1. 统计页（今日/本周番茄柱状图 + 任务分布）— SessionEntity 已备好数据
2. 白噪音（复用 Sounds 资源 + SoundPlayer 模式从 v3 分支抄）
3. Widget（锁屏/桌面小圆环）— 需要重新加回扩展 target
4. Siri 快捷指令 / URL Scheme
