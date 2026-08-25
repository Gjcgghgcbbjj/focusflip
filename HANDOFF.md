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

## v1.2.0 / v1.3.0 增量
- 统计页重做: 渐变英雄卡(连续天数🔥/日均/最常投入) + 圆角柱图(均值虚线/今日高亮)
  + 24小时时段热力条 + 任务占比环形图(Canvas)
- 自由计时器 tab: 秒表(计次)+任意倒计时(chips/通知/提示音), 墙钟派生后台准
- 任务 tab = TODO: 勾选完成/分区/滑动设为当前/改色; 行尾历史累计投入
- 今日时间线卡: 会话时间轴 + 一句话备注(SessionEntity.note, 点条目编辑)
- 日期倒计时: 主屏横幅显示最近目标, CountdownSheet 管理; <=30天红显
- 模型增量: TaskEntity.isDone(default false)/SessionEntity.note(optional)/CountdownEntity
- 真实环境音(BBC Rewind RemArc 个人许可): rain/ocean/forest/fan.m4a,
  loudnorm -22LUFS + acrossfade 无缝循环 + AAC96k; 白粉棕保留合成
- URL Scheme: focusflip://start|pause|resume|skip
- 教训: heredoc 里写 re.sub 的 \d 会被双转义失效 → 版本补丁走 tmp/bump.py 文件方式

---

# v1.4 → v2.6.0 演进全记录（2026-08-24 更新）

## 版本线

| 版本 | 主题 | 要点 |
|------|------|------|
| v1.4.0 | 三问题修复 | 倒计时常驻入口(轮播)/TODO 首次重做/界面精修；确立 **patch 必 assert** 纪律 |
| v1.5.0 | 信息架构重组 | 四 tab 定位：番茄/自由并入专注页、声音归设置、倒计时归统计页顶、任务选择器纯选、CSV 导出 |
| v1.6.0 | 目标独立 tab | 模式切换外提(修"回不去")、渐变顶部减浅提对比度、TODO 添加常驻、目标大卡+空态 |
| v1.7.0 | 崩溃与墨色 | 删任务闪退首修(wasCurrent 时序)；**亮度感知墨色体系**(luminance/ink/inkSoft/panel)——浅色任务色全场景自动深字；设置折叠分组 |
| v1.8.0 | 按钮体量升级 | 对标 Apple Timer/Flow/Things/HIG：热区≥44pt 全覆盖、裸文字→幽灵胶囊/淡底药丸 |
| v1.9.0 | UI 规范化 | **设计令牌 DS.swift 落地**（字号阶梯14种收敛为规范集合/圆角家族 card20/tile7/composer14/组件高度规格）；自由面板改下划线标签；设置图标色块 |
| v2.0.0 | 统计页语言统一 | 任务 tab→insetGrouped 卡片组；自由时间入"统计同款卡"+状态副标题；非沉浸页全部= groupedBackground + R.card 家族 |
| v2.1.0 | 五问题修复 | TabBar 不透明底；模式切换双配色方案(场景墨色/中性)；TODO 行放大+完成三重反馈；目标三档形态+8色自选；**设置整体脱离 Form 重写为卡片家族** |
| v2.2.0 | 闪退根治 | **CoreData 删除崩溃真因**：withAnimation 包 save→diffing 重渲染已删实体。全 App 统一：无动画事务+异步 reload+行构建器 managedObjectContext 守卫；手势语义重排(右滑设当前/左滑全划删除) |
| v2.3.0 | 主流交互包 | **计时器杀后台快照恢复**(eng.snapshot.v1, 后台走完自动结算推进)；5 sheet 半高化(iOS15 桥接 detents+抓手)；阶段完成光晕仪式；删除撤销 Toast(5s)；英雄数字滚动 RollText；PressStyle 升级；触感分级 |
| v2.4.0 | 交互深挖 | 目标可编辑 sheet；秒表最快/最慢圈(Apple Stopwatch 标准)+长按删圈；圆环长按菜单(暂停/跳过/放弃)；目标紧急置顶 |
| v2.5.0 | 数据与下钻 | 统计图例点选按任务下钻过滤；**全屏结算卡**(引擎 lastCompletion 事件驱动)；沉浸模式(tabBar 动画隐藏)；JSON 备份导出/导入(按 ID 合并) |
| v2.6.0 | Calm Productivity Hub 重设计 | 规范 `docs/aegis/specs/2026-08-23-calm-productivity-hub-design-spec.md`，分支 feature/calm-productivity-hub(PR#1)；**设计系统全面升级**(DS.swift：hubSurface 卡面/MetricTile/PillControl/motion tokens/DS.Haptic 集中触感)；专注页圆环·chips·主按钮重制+SettleCard 滑动关闭；自由计时统一控件+环境音入口按钮；任务页 Today Focus 锚点卡+AppRouter 跨 tab 路由；统计分层洞察(range pills/hero 卡/图表卡族/时间线文案)；目标 urgency 卡片(进度环/滑动 postpone·duplicate·delete)；设置两步备份导出导入(计数确认)+CSV 预览+声音面板 PressStyle 精修 |

## 当前文件地图（v2.5.0）

```
Sources/App/FlowSimApp.swift      入口·五Tab(专注/任务/统计/目标/设置)·URL Scheme·不透明TabBar
Sources/Core/
  Theme.swift                     Palette(sceneGradient/deepVariant/taskPalette8)
                                  luminance/ink/inkSoft/panel(亮度感知墨色) · Layout(ringSize/ringWidth)
  DS.swift                        设计令牌: F(字号阶梯)/S(间距)/R(card20,tile7,composer14)/H(组件高度44底线)
                                  SheetDetents(iOS15半高桥) · RollText(数字tween) · Haptic.light()
  Prefs.swift                     autoStart×2/keepAwake/immersive/时长×4/sound×3/tone
  Engine.swift                    墙钟状态机 + saveState/restoreState(eng.snapshot.v1)
                                  + @Published lastCompletion(PhaseCompletion)
  Store.swift                     TaskEntity(id,name,colorHex,isDone,sortOrder,createdAt)
                                  SessionEntity(phaseRaw,start,end,durationSeconds,completed,taskId,note)
                                  CountdownEntity(title,targetDate,colorHex,createdAt)
                                  CRUD+addTaskRaw(撤销重建用)+exportCSV(BOM)
  SoundPlayer.swift               ambientTypes(rain/ocean/forest/fan真实录音+white/pink/brown合成) tones×4
  Services.swift                  KeepAlive(silentWAV+PassthroughSubject tick) Notifications(notifAsked纪律)
  Toast.swift                     ToastCenter(show/undo 5s) + ToastOverlay(底部胶囊)
  Backup.swift                    Payload{tasks,countdowns,sessions} ISO日期 导出/restore按ID合并
Sources/Features/
  HomeView.swift                  homeMode双方案切换/亮度墨色fg族/bloom光晕/SettleCard挂载/
                                  沉浸模式applyImmersive+setTabBar/contextMenu长按/PressStyle定义/Haptic枚举
  TodoView.swift                  insetGrouped卡片组/metaHeader(RollText进度)/快速添加(FocusState自动聚焦+
                                  nextColorHex预览)/行守卫AnyView收口/swipe语义(右设当前左删撤销)/TaskEditSheet
  StatsView.swift                 RangeKind(today/week/month)/英雄RollText/柱图/hourBins/donutCard
                                  (filterChip+donutCardContent)/timelineCard/TimelineAllSheet/ChartCard通用头
  TargetView.swift                countdownCard三档分发(bigCard urgent/pastCard/slimCard)/编辑EditCountdownSheet
  SettingsView.swift              groupCard折叠(iconTile30pt)/自定义行控件(menuButton药丸/stepperRow胶囊±)/
                                  CSV/Backup导入导出(fileImporter)
  FreeTimerView.swift             下划线underTab/stopwatch(laps最快最慢+contextMenu删)/countdown(chips35h)
  SettleCard.swift                全屏结算(对勾弹入/RollText分钟/开始下一阶段/稍后再说)
  Sheets.swift                    TaskPickerSheet(纯选+footer指引)/DurationTuneSheet
```

## 设计系统速查

- 字号只从 `DS.F` 取：display56 / timerLg62 / title1_30 / title2_22 / numberM17 / headline16 / body15×3 / subhead13×2 / caption11 / microCaps10(kerning1.5)
- 圆角：卡片 R.card=20 一律；tile7；composer14
- 高度：主按钮54 / 大圆76 / 幽灵胶囊40 / chips38 / 分段内高34 / 触控≥44(DS.H.touchMin)
- 场景色墨水：`Palette.ink/inkSoft/panel(baseColor)` 按 WCAG 亮度自动黑白翻转——新元素禁止硬编码 .white
- 半透明层：场景上用 panel()，中性页用 secondarySystemGroupedBackground
- 弹层：一律 `.background(SheetDetents())` 挂 navigationTitle 链尾(medium/large+抓手)

## 关键机制备忘

### 引擎持久化（v2.3）
- 键 `eng.snapshot.v1`：state/phase/total/remain/startedAt/taskID
- 写入点：begin/pause/resume/prepare/goIdle 尾部
- 恢复：running→墙钟补偿续跑(重挂KeepAlive+环境音+通知)；remain≤0→finishCurrent(true)+advanceToNext(后台走完自动推进)；paused/prepared 原样；其余 idle
- 完成事件：completePhase() 尾发 `lastCompletion`(minutes/wasFocus/nextPrepared)，HomeView 据此挂 SettleCard；skip/giveUp 不触发

### CoreData 变更纪律（v2.2 血泪）
任何 delete/save 后紧跟 UI 的路径必须：
```swift
var tx = Transaction(); tx.disablesAnimations = true
withTransaction(tx) { Store.shared.deleteX(obj) }
DispatchQueue.main.async { reload() }
```
行构建器头部守卫：`guard obj.managedObjectContext != nil else { return AnyView(EmptyView()) }`（函数签名显式 `-> AnyView`，闭合括号挂在修饰链最末）。
撤销删除用 `Store.addTaskRaw(name:colorHex:)`（不走色轮换），Toast 回调里重建。

### iOS15 兼容红线（持续有效）
无 contentTransition / fontWeight(View版) / scrollContentBackground / TextField(axis:) / NavigationStack / Section(isExpanded:) / .spring(damping:)【要用 dampingFraction】/ onChange 双参数闭包【iOS17】/ presentationDetents【用 SheetDetents 桥】

### 发布流程（现行）
```bash
python3 tmp/bump.py X.Y.Z     # 参数化写 project.yml/plist/workflow 三处, build号自增
git commit + push master      # CI 编译验证
git tag vX.Y.Z && git push origin vX.Y.Z   # 若撞旧项目tag: gh release delete X --yes; git push origin :refs/tags/X
验证: gh release view vX --json assets   # FocusFlip-X.Y.Z.ipa ~5.4MB
```

## 工程血泪清单（新会话必读）

1. **patch 必 assert**——静默 no-op 是两次"发布缺功能"事故根因
2. heredoc 内写 re.sub 的 `\d` 会双重转义 → 版本补丁走 tmp/*.py 文件方式（bump.py 已参数化，勿再硬编码版本）
3. AnyView 包裹多返回路径时，闭合括号必须在**全部修饰链(含 swipeActions/contextMenu)** 之后；中间提前 `)` 会把后续链变孤儿表达式
4. Text+Text 拼接要求两侧都是 Text（.frame 会破坏）；复杂行内组合用 HStack
5. iOS15 spring 参数名是 dampingFraction 不是 damping
6. tag 冲突旧项目遗留 v1.x/v2.x/v3.x——打 tag 前 `git ls-remote --tags | grep` 检查
7. tmp 目录每 bash 调用即焚；持久脚本放 `/root/dsphn/tmp/`
8. 用户反馈的"闪退"优先怀疑：已保存删除实体的属性访问（本仓两大崩溃皆此）

## UI 截图巡游（skill §六闭环，PR#2）

- 每次推送自动产出 `focusflip-ui-tour` artifact：5 tab × 亮/暗共 10 张 + `tour.log`（每张 md5 对比上一 run 打 changed/UNCHANGED，基线走 actions/cache 跨 run）
- **导航：`SIMCTL_CHILD_FF_TAB=<focus|tasks|stats|targets|settings>` 冷启动**（FlowSimApp 读 env 设初始 tab）。**不要用 simctl openurl**——iOS 26 模拟器实测 warm openurl 不投递、冷启动弹「Open in FocusFlip?」确认框；快捷指令深链（focusflip://tab/…）真机待复验
- `FF_UI_TOUR=1`（SIMCTL_CHILD_ 前缀注入）：跳过通知权限弹窗——弹窗会挡导航与截图主体
- 键盘态：任务页输入框 onAppear 0.3s 自动聚焦（TodoView.swift:420），02-tasks 天然带键盘；完整键盘截图看 12-tasks-dark。idb 点按仅 `INSTALL_IDB=1` 时启用——**idb-companion 已移出 homebrew-core，须 `brew tap facebook/fb` 再装**（skill §六的 `brew install idb-companion` 裸命令已失效）
- 巡游是证据不是门禁（continue-on-error）；坐标一律屏幕百分比
- 巡游发现待办：①首页浮动 tab bar 暗色发亮 = iOS 26 Liquid Glass 拾取场景色（其他页正常，观察不盲改）；②任务页日期 zh_CN 硬编码（StatsView:781 / TodoView:549）在英文设备直出中文

## 交互批次（PR#2 后半，2026-08-24）

- **每日番茄目标**：`prefs.dailyGoal`（0=关）；环心「今日 n/goal」、结算卡目标行、达成 Toast（Engine.completePhase 判 `==` 只响一次）
- **通知操作按钮**：FOCUS_DONE/BREAK_DONE category + START_NEXT action；响应在 AppDelegate（@UIApplicationDelegateAdaptor），冷启动也能开跑
- **目标关联任务 + DDL 提醒**：`prefs.targetLinkedTask / targetReminderDays`（UserDefaults 映射，**故意不动 CoreData 模型避免迁移**）；提醒=目标日前 N 天 9 点，删除即取消；目标卡「已投入」用单次 fetch 聚合
- **自由计时落盘**：`FreeTimerModel`（freetimer.snapshot.v1），didSet persist / init restore；倒计时可计入统计（prefs.countdownCounts，默认关，走完记 focus 会话）
- **全年热力图**：StatsView 53 周格子（周一对齐、五档色阶）；⚠️ 巡游截不到（在首屏下方），真机待确认
- **任务拖拽排序**：已撤（editMode+onMove 与 swipeActions 在 iOS15 List 是崩溃族）；sortOrder 字段与 Store.setOrder 保留待后用
- **idle 环预览**：`Engine.displayRemaining` idle 态显示所选时长（25:00），空环语义不变
- 种子钩子：`FF_SEED_DEMO=1` 空库种 3 任务+7 天会话（Store.seedDemoIfEmpty），巡游从此截到有数据的真实形态

## 闪退/手势事故复盘（2026-08-24，已修）

- **症状**：任务页左滑/右滑/添加/删除全坏 + 闪退感 + 动画怪；新旧构建都复现
- **根因**：行级 `.contentShape+.onTapGesture`（旧）/整行 Button（新）与 List swipeActions **手势歧义**——短滑被识别成点击 → 误开编辑页，滑动露出时灵时坏。XCUITest 截屏实锤（滑动后编辑页开着）
- **修复**：整卡 `Button`（点卡=编辑）+ 色圈/播放嵌套 Button（内层在自己范围内优先）；编辑页删除加已删实体守卫（血泪#8）
- **复现环**：`UITests/TodoInteractionTests`（XCUITest + FF_SEED_DEMO）驱动 删除→撤销→设当前→快捷开始→添加→编辑 全叙事，已全绿；CI 非门禁但红了必须看
- **测试基建坑**：嵌套按钮对 XCUITest 不可 hittable → 用坐标点击；跨 tab 用 FF_TAB 冷启动，别点 tab 栏（离屏元素 exists 但不 hittable）
- **教训**：List 行上永远别用裸 onTapGesture 抢点击——用 Button；「旧版也崩」= 根因在共享路径，先 diff 新旧差异集再下结论
- 真机待复验：iOS 15/16 实机手势（模拟器是 iOS 26）

## 任务卡片动画架构（2026-08-25，List → SwipeableCard）

- List 给不出卡片动画（行高瞬塌、无入场），任务页换 `ScrollView+LazyVStack+SwipeableCard`（TodoView.swift 尾部）：拖拽橡皮筋限幅、40%宽/甩动阈值、全扫飞出、露出 128pt 停留可点、插入 scale(.92)+fade+y14 弹簧、移除 slide-fade，事务全在 withAnimation(DS.Motion.soft/quick)
- **动效设计原型**：`docs/animation-mockup.html`（纯前端，弹簧物理与 DS.Motion 同源 k=(2π/r)² c=2ζ√k），playwright 真鼠标验证 20 断言（/root/dsphn/tmp/mocktest/test.mjs+test2.mjs）——**改动画先过模拟器再看真机**
- 踩坑：①.highPriorityGesture 否则快滑被内嵌 Button 抢成 tap ②动作钮必须 accessibilityHidden(未露出)+accessibilityAction，否则常驻 a11y 树，XCUITest firstMatch 点到盖住的钮穿透成卡 tap ③XCUITest 滑动坐标用整卡（task.card.<名>），文本坐标拖距只有几十 pt 只够露出 ④HTML mockup 的 transform 容器要 pointer-events:none 否则挡背后按钮

### UIPan 重做（2026-08-25，底层互动改版第一期）

- SwipeableCard 拖拽换 `SwipePanContainer`（UIHostingController + UIPanGestureRecognizer）：`gestureRecognizerShouldBegin` 按速度门控——竖向让路 ScrollView（滚动不再发黏）、横向 1:1 直接变换 layer（无 SwiftUI 逐帧 diff）、原生速度采样（450pt/s 甩动阈值）
- DragGesture 版的隐藏代价：highPriorityGesture 不分方向，竖滚也被手势吃掉；predictedEnd 的"甩动"与原生速度手感有差
- **新崩溃（血泪#8 变体）**：UIHostingController.updateUIViewController 无条件重建 rootView → 删除后重渲染他卡时访问已删 NSManagedObject → UUID 桥接 SIGTRAP（Foundation._unconditionallyBridgeFromObjectiveC）。修法：cardBody 入口 `guard t.managedObjectContext != nil`。DragGesture 版没暴露是因为它不强制重建
- PressStyle v2：pressHaptic 钩子（按下即触觉，原生键盘感）、r.24 ζ.7、加深按压暗化；圆环/倒计时卡/时间线行/色点全部 Button 化（8 处 onTapGesture 清到 2 处刻意保留）

## Backlog（远期，均未开工）

- 动态字体适配关键文本（现全固定字号，个人自用可接受）
- Live Activity / 锁屏组件（需 iOS16.1+ 与扩展 target，与 iOS15 底线冲突，需条件编译）
- 统计周/月对比视图深化、任务维度时间线复用下钻
- 完成提示音换真录音（用户可随时点名需求）

---
*收官时点：v2.6.0 (build 17)，tag=v2.6.0（feature/calm-productivity-hub 经 PR#1 合入 master）。*
