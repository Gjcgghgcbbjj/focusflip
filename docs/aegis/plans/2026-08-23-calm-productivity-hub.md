# FocusFlip Calm Productivity Hub Implementation Plan

## Goal

Implement the approved `docs/aegis/specs/2026-08-23-calm-productivity-hub-design-spec.md`: retain the five-tab product scope while upgrading FocusFlip into a calm personal-efficiency hub with a shared large-card visual system, precise interactions, richer statistics hierarchy, and GitHub-only Xcode/IPA verification.

## Architecture

- Keep the existing SwiftUI app, five-tab root, programmatic CoreData store, wall-clock engine, notification/sound services, backup flows, TrollStore packaging, and release workflow.
- Introduce the shared presentation vocabulary in `Sources/Core/DS.swift`; feature views may consume tokens/components but must not define competing global design constants.
- Preserve ownership boundaries:
  - Time/state truth remains in `FocusEngine`.
  - Persistence remains in `Store`.
  - Sound remains in `SoundPlayer`.
  - Backup/import remains in `Backup`.
  - Views only orchestrate presentation and user intent.
- No new persistence model, service owner, external dependency, app extension, or release target is permitted.

## Tech Stack

- SwiftUI / UIKit bridging where already used
- iOS 15.0 deployment target
- Programmatic CoreData
- XcodeGen
- GitHub Actions `Build IPA` on macOS

## Baseline/Authority Refs

- Product/design authority: `docs/aegis/specs/2026-08-23-calm-productivity-hub-design-spec.md`
- Current handoff/constraints: `HANDOFF.md`
- Existing design-token owner: `Sources/Core/DS.swift`
- Existing scene-color owner: `Sources/Core/Theme.swift`
- Existing workflow: `.github/workflows/build-ipa.yml`

Requirement Ready Check: ready. The user confirmed the Calm Productivity Hub direction and interaction proposal; the active objective explicitly authorizes implementation and GitHub verification.

## Compatibility Boundary

- Must remain buildable against iOS 15.0.
- Must not use `NavigationStack`, view-version `fontWeight`, `contentTransition`, `.scrollContentBackground`, `TextField(axis:)`, iOS17 two-parameter `onChange`, native `presentationDetents`, or `.spring(damping:)`.
- CoreData deletion paths must continue guarding deleted managed objects.
- Engine snapshot keys, CoreData schema, URL scheme, notification behavior, ambient playback behavior, backup compatibility, CSV export, and IPA packaging must remain functional.
- No release tag is required during implementation.

## Verification

Authoritative build/package verification runs remotely in GitHub Actions because this workspace cannot run Xcode.

For every pushed implementation slice:

```bash
git status --short
rg -n "NavigationStack|contentTransition|scrollContentBackground|TextField\\(axis:|\\.spring\\(damping:" Sources || true
git push -u origin feature/calm-productivity-hub
gh run list --workflow "Build IPA" --limit 3
gh run watch <run-id> --exit-status
```

On failure:

```bash
gh run view <run-id> --log-failed
```

A slice is complete only when the exact commit has a green remote `Build IPA` workflow and an inspectable IPA artifact.

---

## Task 1 — Shared Design System Foundation

Files:

- Modify `Sources/Core/DS.swift`
- Reference-only: `Sources/Core/Theme.swift`
- Consumers touched in later tasks

Why: establish one owner for semantic type, spacing, radius, elevation, motion, cards, metric tiles, pills, and press feedback before UI refactoring.

Impact/Compatibility: additive tokens/components plus controlled replacement of local repeated styling. No business logic or data contract changes.

Verification:

```bash
git status --short
rg -n "NavigationStack|contentTransition|scrollContentBackground|TextField\\(axis:|\\.spring\\(damping:" Sources || true
git push -u origin feature/calm-productivity-hub
gh run watch <run-id> --exit-status
```

Steps:

1. Create feature branch from current master.
2. Extend `DS` without removing existing symbols consumed by current views.
3. Add reusable continuous-corner card, metric-tile, pill, section-header, and press-style components.
4. Ensure all new APIs are iOS15-safe.
5. Commit and push; require green GitHub Actions.

## Task 2 — Focus Tab Presentation Pass

Files:

- Modify `Sources/Features/HomeView.swift`
- Modify `Sources/Features/SettleCard.swift`

Why: make focus the emotional center and improve Apple Timer/Flow-style control quality.

Impact/Compatibility: presentation and interaction only. `FocusEngine` state transitions, snapshot recovery, notifications, keep-alive, URL scheme, and session recording remain unchanged.

Verification: Task 1 command set plus source checks that primary actions map to existing engine methods.

Steps:

1. Apply unified pill/card/control styles to mode switch, task header, chips, main controls, and side controls.
2. Improve running/paused ring hierarchy and press affordances without changing timing math.
3. Refine settle-card elevation, action hierarchy, and dismissal feedback.
4. Verify engine calls and lifecycle hooks are unchanged.
5. Commit, push, and require a green exact-commit workflow.

## Task 3 — Free Timer Presentation and Interaction

Files:

- Modify `Sources/Features/FreeTimerView.swift`

Why: give stopwatch/countdown the same control language as Pomodoro.

Impact/Compatibility: state variables and wall-clock formulas stay unchanged; notification and tone behavior stays unchanged.

Steps:

1. Replace underline tabs with capsule segmented controls.
2. Apply shared timer display, circular controls, metric/list-card treatment, and haptics.
3. Preserve stopwatch accumulation, lap calculations, countdown pause/resume, reset, notification scheduling, and completion tone.
4. Push exact commit and require green workflow.

## Task 4 — Tasks Tab Today Anchor and List Polish

Files:

- Modify `Sources/App/FlowSimApp.swift`
- Modify `Sources/Features/TodoView.swift`
- Possibly modify `Sources/Features/Sheets.swift`

Why: establish Things-style calm hierarchy with a Today Focus anchor and refined row interactions.

Impact/Compatibility: preserve Store CRUD, current-task selection, undo deletion, deleted-object guards, completed grouping, and accumulated-time calculations.

Steps:

1. Add Today Focus anchor using selected/current task, today's totals, and start/resume action.
2. Normalize list rows, color dots, check animation, composer, empty states, and section headers through shared components.
3. Preserve right-swipe current selection, left-swipe undo deletion, long-cut actions, and deleted-entity guards.
4. Push exact commit and require green workflow.

## Task 5 — Stats Insight Hierarchy

Files:

- Modify `Sources/Features/StatsView.swift`

Why: transform chart stacking into layered insight while preserving all analytics capabilities.

Impact/Compatibility: queries/date ranges/aggregations remain owned locally but unchanged unless required by presentation; CoreData read paths must remain safe.

Steps:

1. Normalize range pills, Hero Card, chart cards, timeline rows, donut filtering, and empty states with shared components.
2. Clarify order: hero, today/trend, task share, hour distribution, timeline/highlights.
3. Preserve CSV export inputs, notes editing, drill-down filtering, and all existing metrics.
4. Push exact commit and require green workflow.

## Task 6 — Targets Urgency Cards

Files:

- Modify `Sources/Features/TargetView.swift`
- Possibly modify `Sources/Features/CountdownSheet.swift`

Why: turn targets into date cards with clear urgency tiers and progress.

Impact/Compatibility: CountdownEntity CRUD, sorting, edit sheet, and date calculations remain compatible.

Steps:

1. Apply tiered urgency treatments and shared date-card layout.
2. Clarify tap/edit, swipe/delete, long-cut, overdue, and empty-state interactions.
3. Preserve entity safety after deletion.
4. Push exact commit and require green workflow.

## Task 7 — Settings, Sound, Backup Consistency

Files:

- Modify `Sources/Features/SettingsView.swift`
- Modify `Sources/Features/SoundSheet.swift`
- Possibly reference `Sources/Core/Backup.swift`

Why: bring low-frequency paths into the same calm hub language and clarify destructive/import operations.

Impact/Compatibility: preserve preference keys, sound identifiers, CSV generation, JSON merge-by-ID import, ShareSheet, and preview behavior.

Steps:

1. Normalize collapsed groups, rows, controls, sound sheet, and confirmation dialogs.
2. Make JSON import preview/confirmation copy explicit while retaining existing restore semantics.
3. Avoid changing persisted preference keys or backup format.
4. Push exact commit and require green workflow.

## Task 8 — Completion Audit

Files:

- Modify only documentation/checkpoint files if needed.

Why: prove every accepted spec requirement is represented in current source and remote CI.

Steps:

1. Run requirement-to-source audit across DS/focus/free/tasks/stats/target/settings/data.
2. Run forbidden-API and repository-status checks.
3. Confirm latest exact-commit GitHub Actions workflow is green and produced an IPA artifact.
4. Summarize implemented scope, deferred non-goals, remaining risks, and evidence.

Rollback surface: each task is a small commit on `feature/calm-productivity-hub`; rollback is `git revert <commit>` followed by another GitHub Actions run. No database migration or release tag is involved.
