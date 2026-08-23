# 🍅 FocusFlip

> Flow 风格极简番茄钟 · SwiftUI · iOS 15+ · 个人自用
> 通过 [TrollStore](https://github.com/opa334/TrollStore) 安装 GitHub Releases 的 IPA 即可使用

**最新版本：[v2.5.0](https://github.com/Gjcgghgcbbjj/focusflip/releases/download/v2.5.0/FocusFlip-2.5.0.ipa)**
（任意版本：`https://github.com/Gjcgghgcbbjj/focusflip/releases/download/vX.Y.Z/FocusFlip-X.Y.Z.ipa`）

---

## 核心体验（Flow 三要素）

1. **色即界面** —— 选中任务的颜色铺满整屏（上浅下深渐变），阶段切换平滑过渡；
   未选任务=靛蓝 `#5865F2`，小憩=绿，长歇=蓝。浅色任务色自动切换深墨文字（WCAG 亮度感知）
2. **大圆环细字** —— 大圆环 + 56pt 圆体时间；点环暂停/继续，长按呼出快捷菜单
3. **时长快选 chips** —— 常用时长一排胶囊 + `···` 精调面板

## 功能总览

| 模块 | 能力 |
|------|------|
| ⏱ 专注 | 番茄循环（长歇间隔可设）/ 自动接续开关 / 完成光晕仪式 / 全屏结算卡 |
| 🕐 自由计时 | 秒表（最快最慢圈高亮·计次可删）+ 任意倒计时（chips/通知/提示音） |
| ✅ 任务 | Things 式列表（色圈勾选弹簧反馈/已完成折叠）/ 快速添加自动聚焦 / 右滑设当前 · 左滑删除(可撤销) / 行尾累计投入 |
| 📊 统计 | 渐变英雄卡（番茄数滚动/连续天数🔥/日均/最常投入）/ 日柱图(均值虚线) / 24h 时段 / 任务占比环形图 / **点图例按任务下钻过滤** / 今日时间线+备注 |
| 🎯 目标 | 日期倒计时三档形态卡（≤7天火焰徽章 / >30天横条 / 过期灰卡）/ 8 色自选 / 可编辑 / 紧急置顶 |
| ⚙️ 设置 | 卡片化分组（默认折叠）/ 行为·声音·时长·数据·关于 |
| 🔊 声音 | 真实环境音（雨/海浪/森林/风扇，BBC Rewind RemArc 许可）+ 白粉棕噪声 + 4 种完成提示音，均带试听 |
| 💾 数据 | CSV 导出（BOM 兼容中文 Excel）/ **JSON 全量备份与导入**（按 ID 去重合并） |

### 可靠性设计

- **墙钟引擎**：`startedAt + totalSeconds` 单一真相源，后台不漂移
- **杀后台恢复**：状态快照落盘（`eng.snapshot.v1`），重进无缝续跑；后台走完自动结算推进
- **通知预约**：仅专注/倒计时阶段，权限只在首次询问时记录
- **URL Scheme**：`focusflip://start|pause|resume|skip`
- **沉浸模式**：可选"计时中隐藏底部标签栏"

## 从源码构建

```bash
brew install xcodegen
cd focusflip && xcodegen generate
open FocusFlip.xcodeproj   # 选好签名 Team 后 Cmd+R
```

CI：推 tag `vX.Y.Z` → GitHub Actions（macos-15）约 7 分钟产出未签名 IPA 并挂到 Releases。

发版流程（本地）：`python3 tmp/bump.py X.Y.Z`（参数化改三处版本号）→ commit → push master → 打 tag。

## 工程结构

```
Sources/
├── App/FlowSimApp.swift        # 入口·五 Tab·URL Scheme·TabBar 外观
├── Core/
│   ├── Theme.swift             # Palette/场景渐变/亮度墨色/Layout
│   ├── DS.swift                # 设计令牌(字号阶梯/间距/圆角/组件高度)+SheetDetents+RollText
│   ├── Prefs.swift             # UserDefaults 偏好
│   ├── Engine.swift            # 墙钟状态机 + 快照恢复 + 完成事件发布
│   ├── Store.swift             # CoreData 程序化模型(Task/Session/Countdown)+CRUD+CSV
│   ├── SoundPlayer.swift       # 环境音/提示音
│   ├── Services.swift          # KeepAlive(静音WAV保活)+Notifications
│   ├── Toast.swift             # 全局撤销 Toast
│   └── Backup.swift            # JSON 备份/恢复
└── Features/
    ├── HomeView.swift          # 主屏(模式切换/圆环/chips/结算卡/沉浸钩子)
    ├── TodoView.swift          # 任务 tab
    ├── StatsView.swift         # 统计 tab(下钻过滤)
    ├── TargetView.swift        # 目标 tab(+编辑 sheet)
    ├── SettingsView.swift      # 设置(卡片化折叠分组)
    ├── FreeTimerView.swift     # 自由计时面板(下划线标签)
    ├── SettleCard.swift        # 阶段完成全屏结算卡
    └── Sheets.swift            # 任务选择/时长微调
Resources/Sounds/               # BBC 真录音 m4a ×4 + 合成 wav
```

完整演进史与工程纪律见 [HANDOFF.md](HANDOFF.md)。

## 许可

个人自用项目。环境音采样来自 BBC Sound Effects (RemArc Licence)，仅限个人非商用。
