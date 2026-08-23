# FocusFlip — Calm Productivity Hub Design Spec

Date: 2026-08-23  
Status: Approved for implementation  
Product direction: Personal efficiency hub  
Design direction: Calm Productivity Hub  

## 1. Goal

Upgrade FocusFlip from a feature-complete but visually flat Pomodoro app into a calm, polished personal efficiency hub.

The redesign keeps the existing five-tab information architecture and core data model, while rebuilding the perceived quality of every module through a unified card system, richer statistics, precise interactions, restrained motion, and consistent haptic feedback.

Primary success criteria:

1. The app reads as a personal efficiency hub, not only a Pomodoro timer.
2. Focus remains the emotional center of the product.
3. Tasks, stats, targets, free timer, sounds, and backup feel like parts of one system.
4. Every primary surface has clear hierarchy and large-card structure.
5. Interactions are predictable: tap for primary action, long-press for shortcuts, swipe for low-frequency actions.
6. Visual quality approaches the polish level of Apple Timer, Structured, Things 3, and Flow.

Non-goals for this design phase:

1. Do not remove or merge existing tabs.
2. Do not introduce account systems, cloud sync, AI planning, or team features.
3. Do not replace CoreData.
4. Do not break iOS 15 compatibility.
5. Do not add Live Activity or widget extensions in this pass.
6. Do not change release packaging or TrollStore workflow.

## 2. Product Principles

### 2.1 Calm, not busy

Information should be layered. Each screen answers one primary question before exposing secondary detail.

### 2.2 Cards carry content

Content lives in continuous-corner large cards with clear roles:

- Hero Card: one dominant summary.
- Standard Card: module-level grouping.
- Metric Tile: compact numeric insight.
- List Row: repeatable item.
- Chart Card: visualization container.
- Action Pill: compact primary or secondary control.

### 2.3 Controls feel real

Interactive cards and controls must have visible press feedback, subtle scale, shadow compression, and haptics where appropriate.

### 2.4 Motion is restrained

Animations should clarify state changes, not decorate the screen. Use short spring/ease transitions, number rolling, stroke drawing, and gentle fade/slide movement.

### 2.5 Reference blend

| Reference | Borrowed quality |
|---|---|
| Apple Timer | Large controls, precise feedback, physical buttons |
| Flow | Immersive ring, color-as-state, quiet focus experience |
| Things 3 | Calm hierarchy, elegant lists, refined completion interaction |
| Structured | Timeline feeling, schedule-like presentation, colorful segments |

## 3. Global Design System Requirements

### 3.1 Color

Focus retains task-color full-screen scene treatment:

- Default focus: `#5865F2`
- Short break: `#2FA84F`
- Long break: `#1E88C7`

Neutral surfaces use light system backgrounds and white/near-white cards. Task colors may enter neutral pages through small dots, progress bars, selected states, and chart segments, but neutral tabs must not become full-color scenes.

Text on colored focus scenes continues to use luminance-aware ink colors. Hard-coded `.white` remains forbidden for new elements.

### 3.2 Typography

Typography must use a constrained rounded/system scale. Minimum required semantic styles:

- Display timer
- Hero metric
- Page title
- Section title
- Card title
- Body
- Secondary body
- Caption / metadata
- Micro caption

Numbers in timers, metrics, charts, and dates should use monospaced digits where alignment matters.

### 3.3 Spacing and radius

Establish consistent spacing tiers and card padding. Prefer fewer, larger spacing steps over dense ad-hoc values.

Required radius roles:

- Screen card: continuous corner
- Embedded tile: smaller continuous corner
- Composer/input: medium radius
- Pill/chip: capsule

### 3.4 Elevation and material

Cards require subtle depth without heavy shadows:

- Resting card: very soft shadow.
- Pressed card: slight scale down and compressed shadow.
- Overlay/settle card: stronger elevation than standard cards.
- Focus scene: color gradient and ring remain dominant; avoid noisy glass effects.

### 3.5 Motion

Baseline motion:

- Card entrance: fade plus slight upward offset.
- Button press: quick spring scale.
- Completion/checkmark: stroke animation.
- Numeric updates: roll/tween where meaningful.
- Ring transitions: smooth sweep and color transition.
- Sheet presentation: standard detents with grabber.

All animations must respect iOS 15-compatible APIs.

### 3.6 Haptics

| Event | Feedback |
|---|---|
|普通点选 | Light |
|开始专注 | Medium |
|完成番茄 | Success/notification |
|删除确认 | Warning |
|勾选任务 | Light + spring |
|进入沉浸模式 | Soft/light |

## 4. Global Interaction Rules

### 4.1 Gesture model

| Gesture | Meaning |
|---|---|
| Tap | Primary action |
| Long-press | Shortcut menu or advanced operation |
| Right swipe | Positive action, such as set current |
| Left swipe | Neutral/destructive action, such as delete |
| Pull down | Close immersive state or refresh where justified |
| Drag | Reorder only in explicit edit mode |

### 4.2 Feedback contract

Every user action must produce at least one of:

1. Visible state transition.
2. Haptic response.
3. Toast confirmation/undo.
4. Contextual error message.

Silent no-op is forbidden.

### 4.3 Destructive actions

Destructive actions require either undo toast or explicit confirmation when data/history loss is possible. Deleting a task should preserve historical sessions by default so statistics remain trustworthy.

## 5. Focus Tab

### 5.1 Role

Focus remains the immersive emotional center. It combines Pomodoro and Free Timer modes but must not become a dashboard.

### 5.2 Pomodoro mode

Top context:

```text
当前任务 · 小色点
```

Tap opens task picker.

Center:

- Keep the large ring and time as the visual protagonist.
- Running ring has extremely subtle life; avoid loud glow.
- Paused state reduces time-text emphasis and stops ring progression.
- Phase label and current task remain readable.

Duration chips:

```text
15 · 20 · 25 · 30 · 45 · 60 · ···
```

Behavior:

- Selected chip becomes filled and slightly enlarged.
- Chips are freely switchable while idle/paused-before-start.
- Changing duration while running requires reset confirmation.
- `···` opens precision tuning sheet.

Main button mapping:

| State | Primary action |
|---|---|
| Idle | 开始专注 |
| Running | 暂停 |
| Paused | 继续 |
| Prepared | 开始休息 |

Secondary controls:

- Reset.
- Skip.

Ring long-press menu:

```text
暂停 / 继续
跳过
放弃
更换任务
调整时长
```

### 5.3 Completion settle moment

After completing a focus session, show a brief settle card:

```text
专注 25 分钟
“写项目方案”
下一阶段：小憩 5 分钟
```

Rules:

- Auto-start mode advances automatically after a short delay.
- Manual mode requires “开始休息” or “稍后”.
- Swipe up or tapping background dismisses the settle card.
- Skip/give-up does not trigger the successful completion ritual.

### 5.4 Free Timer mode

Mode switching uses a lightweight pill control:

```text
番茄 | 自由
```

Free Timer contains two submodes:

```text
秒表 | 倒计时
```

Stopwatch behavior:

- Main button starts/pauses.
- Lap button appears while running.
- Laps expand from below.
- Fastest and slowest laps receive automatic highlight.

Countdown behavior:

- Reuse duration chips and tuning language.
- Notification and tone fire on completion.
- Common countdown presets can be saved later.

### 5.5 Ambient sound entry

During running focus, provide a lightweight ambient sound entry showing icon/current source.

Sound sheet behavior:

- Selecting a source switches immediately.
- Current source is highlighted.
- Volume slider appears in the sheet.
- Playback continues after closing the sheet.
- Focus page reflects active source.

## 6. Tasks Tab

### 6.1 Role

Tasks should feel closest to Things 3: quiet, structured, fast, and elegant.

### 6.2 Today Focus Card

Place a large anchor card at the top:

```text
当前投入
写项目方案
今天已专注 1h 25m · 3 个番茄
[开始]
```

Rules:

- No current task: show “选择一个任务开始”.
- Active focus: show live progress and return-to-focus action.
- Tap card opens task detail/context.
- Action button returns to Focus Tab and starts/resumes appropriate work.

### 6.3 Add task

Use a pinned bottom composer:

```text
＋ 新任务
```

Behavior:

- Tap focuses keyboard automatically.
- Return creates the task while keeping composer active for rapid entry.
- Creation gives light haptic without dismissing keyboard.
- New row enters with a brief slide-in.
- Duplicate names are allowed unless explicitly rejected by future spec.

### 6.4 List structure

Preferred grouping:

```text
当前
待办
已完成
```

Rules:

- Only one task can be current.
- Completed group defaults to collapsed.
- Empty groups hide headers and show graceful empty state only where needed.

### 6.5 Row interactions

| Interaction | Result |
|---|---|
| Tap row | Open task detail |
| Check circle | Complete task |
| Right swipe | Set as current |
| Left swipe | Delete with undo |
| Long-press | Shortcut menu |

Long-press menu:

```text
设为当前
改颜色
编辑名称
查看统计
删除
```

### 6.6 Completion animation

Check interaction sequence:

1. Circle contracts slightly.
2. Circle fills with task color.
3. White check draws with stroke animation.
4. Title moves to secondary style.
5. Light haptic fires.
6. After a short delay, completed row moves to completed section.

### 6.7 Delete policy

- Simple delete shows undo toast.
- If the task has accumulated focus history, confirm intent before deletion.
- Preferred data rule: deleting the task removes the task entity but preserves SessionEntity records and aggregate history.

## 7. Stats Tab

### 7.1 Role

Stats should answer “how am I doing?” through layered insights, not raw chart stacking.

### 7.2 Range selector

Use pill selector:

```text
今日 | 本周 | 本月 | 全部
```

Selected range uses accent fill; unselected items remain quiet.

### 7.3 Hero Card

First card summarizes the range:

```text
2h 35m
4 个番茄 · 连续 6 天
较昨日 +35m
```

Requirements:

- One dominant duration.
- Small supporting metrics.
- Optional mini trend/ring.
- Comparison against previous equivalent period when available.
- No equal visual weight for all metrics.

### 7.4 Today view

Order:

1. Hero Card.
2. Current-task investment card.
3. Today timeline.
4. Hour distribution.
5. Task share.

Today timeline format:

```text
09:00 - 09:25   写项目方案   25m
10:10 - 10:35   阅读         25m
14:00 - 14:45   修 Bug       45m
```

Interactions:

- Tap a session to expand/edit note.
- Long-press for copy/delete options.
- Consecutive sessions from the same task may be grouped:
  ```text
  写项目方案 · 3 个番茄 · 75m
  ```

### 7.5 Week/month/all view

Order:

1. Hero Card.
2. Bar trend.
3. Task share donut.
4. Time-of-day heat/distribution.
5. Highlights: best day, most invested task.

Bar chart rules:

- Highest day is highlighted.
- Average line uses dashed styling.
- Tap selects a day.
- Selected day can open day-detail view.

Donut rules:

- Tap segment filters by task.
- Tapping same segment again clears filter.
- Legend chips mirror selection state.
- Center displays current scope:
  ```text
  全部 · 8h 20m
  ```
  or
  ```text
  写项目方案 · 3h 05m
  ```

### 7.6 Empty states

Range-specific empty copy:

- Today: 今天还没有专注记录。
- Week: 这周还比较安静。
- Filtered no result: 这个任务在该范围内没有记录。

## 8. Targets Tab

### 8.1 Role

Targets become a date-card system emphasizing urgency and progress, rather than a plain list.

### 8.2 Target card

Each card shows:

```text
发布 FocusFlip v3
还有 12 天
9 月 4 日
进度环
```

Visual tiers:

| Remaining | Treatment |
|---|---|
| ≤ 7 days | Strong urgency, flame badge, higher saturation |
| 8–30 days | Standard colorful card |
| >30 days | Quiet neutral card |
| Expired | Grey card with red expired badge |

### 8.3 Sorting

Default urgency sort:

1. Expired.
2. ≤7 days.
3. ≤30 days.
4. Further away.
5. Missing/invalid date.

Within the same tier, earlier target date comes first.

### 8.4 Interactions

| Interaction | Result |
|---|---|
| Tap card | Edit/details |
| Long-press | Shortcut menu |
| Right swipe | Mark complete |
| Left swipe | Delete with protection |
| Drag | Manual order only when smart sorting disabled |

Long-press menu:

```text
编辑
复制目标
推迟 1 天
推迟 7 天
标记完成
删除
```

### 8.5 Create/edit sheet

Fields:

```text
标题
目标日期
颜色
备注
```

Validation:

- Title required.
- Past target date allowed with explicit “将显示为已过期” warning.
- Save produces visible success feedback.

## 9. Sounds

Sounds are an accessory layer to focus, not another heavyweight destination.

Ambient sources:

```text
无
雨
海浪
森林
风扇
白噪声
粉噪声
棕噪声
```

Interaction:

- Selection starts/plays immediately.
- Current selection is highlighted.
- Volume slider appears in the sheet.
- Closing the sheet does not stop playback.
- Returning to Focus shows current source.

Completion/alert tones are configured in Settings and support preview.

## 10. Settings and Data

### 10.1 Settings structure

Collapsed groups:

```text
行为
声音
时长
外观
数据
关于
```

### 10.2 CSV export

Before share sheet, show expected record count:

```text
导出 128 条会话记录
```

Export uses ShareSheet directly after generation.

### 10.3 JSON backup export

Show summary before export:

```text
任务 18
会话 320
目标 5
```

### 10.4 JSON restore/import

Import must be two-step:

1. Select file and preview counts/conflicts.
2. User confirms merge.

Preview copy example:

```text
将导入任务 12、会话 180、目标 3
冲突项将按 ID 合并
```

Success toast:

```text
已导入 195 条记录
```

Import failure must leave existing local data usable and show actionable error text.

## 11. Implementation Order

Implementation must proceed in this order:

1. Design-system upgrade.
2. Focus tab rebuild.
3. Tasks tab rebuild.
4. Stats tab rebuild.
5. Targets tab rebuild.
6. Settings/data/free-timer/detail polish.

Each stage must be independently buildable and verifiable.

## 12. Engineering Constraints

These project rules remain mandatory:

1. Target iOS 15.0.
2. Forbidden APIs include:
   - `NavigationStack`
   - View-version `fontWeight`
   - `contentTransition`
   - `.scrollContentBackground`
   - `TextField(axis:)`
   - iOS17 double-parameter `onChange`
   - `.spring(damping:)`; use `dampingFraction`.
   - Native `presentationDetents`; continue using `SheetDetents` bridge.
3. Programmatic CoreData fetch requests must be explicitly typed.
4. Any UI path following entity deletion must avoid accessing deleted managed objects.
   - Disable animations around destructive store mutation where required.
   - Reload asynchronously.
   - Guard rows whose managed object context is nil.
5. Patches must assert actual replacement/application; silent no-op patches are forbidden.
6. Version bumps use parameterized scripts, not hard-coded repeated edits.

## 13. Acceptance Criteria

A redesigned surface passes only if all are true:

1. Uses shared DS/design-system components instead of introducing local one-off visual constants.
2. Has explicit hierarchy: hero/content/action/meta.
3. All interactive elements meet minimum touch target.
4. Press/hover-equivalent/selected/disabled states are visually distinguishable.
5. Motion is present where state changes but does not delay interaction.
6. Destructive paths have undo or confirmation.
7. Empty/error states are designed, not blank.
8. The remote GitHub Actions `Build IPA` workflow passes on the exact commit.
9. The workflow produces an inspectable unsigned TrollStore-compatible IPA artifact.
10. Source review covers create/read/update/delete flows relevant to the changed tab; any device/simulator smoke check is recorded as a follow-up when not executable in CI.
11. No regression risk remains unreviewed for engine persistence, notification scheduling, ambient playback, backup import/export, or task/session statistics.

## 14. Open Items for Later Specification

These are intentionally deferred:

1. Dynamic type support.
2. Widget/Live Activity.
3. Cloud sync.
4. Natural-language task parsing.
5. Advanced goal dependencies/projects.
6. Weekly/monthly comparative deep-dive beyond first redesign.

## 15. Verification Environment

All Swift/Xcode/IPA verification must run in GitHub Actions, not on the current Linux working copy.

Confirmed baseline:

- Repository: `Gjcgghgcbbjj/focusflip`
- GitHub CLI account: `Gjcgghgcbbjj`, active with `repo` and `workflow` scopes.
- Latest `master` push workflow `Build IPA` completed successfully.

### 15.1 Required CI gates

Every redesign commit pushed to a feature branch or `master` must pass the existing GitHub Actions flow:

1. Generate the Xcode project with XcodeGen.
2. Build a Release archive for generic iOS without code signing.
3. Build for the iOS Simulator with deployment target iOS 15.0.
4. Package the TrollStore-compatible unsigned IPA.
5. Publish/upload the resulting artifact according to the current workflow.

A change is not verified until the remote `Build IPA` workflow is green and its IPA artifact is inspectable.

### 15.2 Remote verification command contract

Use `gh` from the workspace to monitor verification:

```bash
gh run list --workflow "Build IPA" --limit 5
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed
```

For release/tag validation:

```bash
gh release view vX.Y.Z --json assets
```

Tag creation must first check remote tags to avoid legacy FocusFlip version conflicts.

### 15.3 Failure policy

If CI fails:

1. Fetch failed logs with `gh run view <run-id> --log-failed`.
2. Reproduce the failing compiler/API constraint from the log.
3. Fix only the failing scope.
4. Push and require a fresh green workflow.
5. Never claim completion from local syntax inspection alone.

Because the current workspace cannot execute Xcode, local checks are limited to source consistency, patch assertions, repository status, documentation/spec review, and preparing commits. Compilation, simulator build, packaging, and artifact validation are authoritative only in GitHub Actions.
