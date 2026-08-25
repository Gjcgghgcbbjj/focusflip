#!/bin/bash
# =============================================================================
# FocusFlip UI 截图巡游（skill §六 CI 截图验证闭环）
#
# 用法（由 build-ipa.yml 调用，也可本地对已 boot 的模拟器手动跑）:
#   DEVICE=<udid> FF_UI_TOUR=1 OUT_DIR=build/tour PREV_DIR=tour-prev ./Scripts/ui-tour.sh
#
# 导航方式（iOS 26 模拟器实测结论）:
#   simctl openurl 自定义 scheme —— warm 不投递、冷启动弹「Open in?」确认框，
#   全部不可用；故用 SIMCTL_CHILD_FF_TAB=<tab> 冷启动，零点按确定性导航。
#
# 流程: 亮色五 tab（每 tab 冷启动）→ 键盘态(需 INSTALL_IDB=1，尽力)
#       → 暗色一轮 → md5 对比上一 run 写 tour.log → 存档供缓存
#
# 纪律: 巡游是证据不是门禁——单点失败记 SKIP/MISSING 继续，不 fail 构建。
# =============================================================================
set -uo pipefail

DEVICE="${DEVICE:?need DEVICE udid}"
BUNDLE_ID="${BUNDLE_ID:-com.focusflip.app}"
OUT_DIR="${OUT_DIR:-build/tour}"
PREV_DIR="${PREV_DIR:-tour-prev}"
INSTALL_IDB="${INSTALL_IDB:-0}"   # 1=尝试装 idb（facebook/fb tap，慢，仅键盘态需要）
mkdir -p "$OUT_DIR" "$PREV_DIR"
LOG="$OUT_DIR/tour.log"
: > "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

sim() { xcrun simctl "$@"; }

shot_file() { # $1 = dest path
  sim io "$DEVICE" screenshot "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------- tap（可选）
# 仅键盘态需要点按。降级链: simctl ui tap → idb (skill §六)。
TAP_BACKEND="none"
PW=390; PH=844

probe_points() {
  local png="$OUT_DIR/.probe.png"
  sim io "$DEVICE" screenshot "$png" >/dev/null 2>&1 || return 1
  local w h
  w=$(sips -g pixelWidth "$png" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$png" 2>/dev/null | awk '/pixelHeight/{print $2}')
  rm -f "$png"
  [ -z "$w" ] || [ -z "$h" ] && { echo "390x844"; return; }
  local scale=3
  [ "$w" -lt 900 ] && scale=2
  echo "$((w / scale))x$((h / scale))"
}

detect_tap_backend() {
  if [ "$INSTALL_IDB" != "1" ]; then
    log "[tap] INSTALL_IDB!=1, skip tap backend (keyboard shot will be MISSING)"
    return
  fi
  if sim ui "$DEVICE" tap 100 100 >/dev/null 2>&1; then
    TAP_BACKEND="simctl"; return
  fi
  if command -v idb >/dev/null 2>&1; then
    TAP_BACKEND="idb"; return
  fi
  log "[tap] installing idb via facebook/fb tap (core formula was removed)..."
  if brew tap facebook/fb >/dev/null 2>&1 \
     && brew install idb-companion >/dev/null 2>&1 \
     && python3 -m pip install --break-system-packages -q fb-idb >/dev/null 2>&1; then
    TAP_BACKEND="idb-shim"; return
  fi
  { echo "--- idb install tail ---"; tail -5 < <(brew install idb-companion 2>&1) || true; } >> "$LOG"
  log "[tap] WARN idb unavailable; keyboard shot will be MISSING"
}

idb_shim() { # Python>3.12 event-loop shim for fb-idb (skill §四血泪)
  python3 -c '
import asyncio, sys
try: asyncio.get_event_loop()
except RuntimeError: asyncio.set_event_loop(asyncio.new_event_loop())
from idb.cli.main import main
main()
' "$@"
}

tap_pct() { # $1=x% $2=y%
  local x=$(( PW * $1 / 100 ))
  local y=$(( PH * $2 / 100 ))
  case "$TAP_BACKEND" in
    simctl) sim ui "$DEVICE" tap "$x" "$y" >/dev/null 2>&1 ;;
    idb)    idb ui tap "$x" "$y" >/dev/null 2>&1 ;;
    idb-shim) idb_shim ui tap "$x" "$y" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- 导航
# 冷启动 + FF_TAB 环境变量：唯一在 iOS 26 模拟器上可靠的免点按导航
goto_tab() { # $1=tab名
  sim terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 0.8
  SIMCTL_CHILD_FF_UI_TOUR=1 SIMCTL_CHILD_FF_TAB="$1" SIMCTL_CHILD_FF_SEED_DEMO=1 \
    sim launch "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 \
    || log "[nav] WARN launch tab/$1 failed"
  wait_rendered
}

# 等首帧渲染完成：白屏 PNG 极小（<100K），渲染后 >=160K；轮询截图字节大小
wait_rendered() {
  local tmp="$OUT_DIR/.ready-probe.png" i sz
  for i in 1 2 3 4 5 6 7 8 9 10; do
    shot_file "$tmp" >/dev/null 2>&1 || { sleep 0.7; continue; }
    sz=$(stat -f%z "$tmp" 2>/dev/null || stat -c%s "$tmp" 2>/dev/null || echo 999999)
    if [ "$sz" -gt 120000 ]; then rm -f "$tmp"; sleep 0.3; return 0; fi
    sleep 0.7
  done
  rm -f "$tmp"
  log "[nav] WARN render probe timeout, continuing"
  return 0
}

# ---------------------------------------------------------------- md5 对比记录
record() { # $1=文件路径 $2=名字
  local f="$1" name="$2" md5 tag
  if [ ! -s "$f" ]; then
    log "[MISSING] $name"
    return
  fi
  md5=$(md5 -q "$f" 2>/dev/null || md5sum "$f" | awk '{print $1}')
  local prev="$PREV_DIR/$name"
  if [ -s "$prev" ] && [ "$(md5 -q "$prev" 2>/dev/null || md5sum "$prev" | awk '{print $1}')" = "$md5" ]; then
    tag="UNCHANGED"
  else
    tag="changed"
  fi
  log "[$tag] $name md5=$md5"
  cp -f "$f" "$PREV_DIR/$name"
}

# ---------------------------------------------------------------- 主流程
echo "== FocusFlip UI tour =="
log "[tour] FF_UI_TOUR=${FF_UI_TOUR:-0} INSTALL_IDB=$INSTALL_IDB"
if PTS=$(probe_points); then PW="${PTS%x*}"; PH="${PTS#*x}"; fi
log "[tour] device points: ${PW}x${PH}"

# 1) 亮色巡游（app 已被 workflow 以 FF_UI_TOUR=1 启动，无权限弹窗）
goto_tab focus    && shot_file "$OUT_DIR/01-home.png"     && record "$OUT_DIR/01-home.png" 01-home.png
goto_tab tasks    && shot_file "$OUT_DIR/02-tasks.png"    && record "$OUT_DIR/02-tasks.png" 02-tasks.png
goto_tab stats    && shot_file "$OUT_DIR/03-stats.png"    && record "$OUT_DIR/03-stats.png" 03-stats.png
goto_tab targets  && shot_file "$OUT_DIR/04-targets.png"  && record "$OUT_DIR/04-targets.png" 04-targets.png
goto_tab settings && shot_file "$OUT_DIR/05-settings.png" && record "$OUT_DIR/05-settings.png" 05-settings.png

# 2) 键盘态（尽力）：任务页顶部输入框；坐标下一轮按实拍修
if [ "$INSTALL_IDB" = "1" ]; then
  detect_tap_backend
  log "[tour] tap backend: $TAP_BACKEND"
  goto_tab tasks
  if tap_pct 50 17; then
    sleep 1.5
    shot_file "$OUT_DIR/06-tasks-keyboard.png"
    record "$OUT_DIR/06-tasks-keyboard.png" 06-tasks-keyboard.png
    tap_pct 50 60 || true
    sleep 0.6
  else
    log "[MISSING] 06-tasks-keyboard.png (no tap backend)"
  fi
else
  log "[MISSING] 06-tasks-keyboard.png (INSTALL_IDB!=1)"
fi

# 3) 暗色一轮（skill: simctl ui appearance dark 再截一轮；外观是模拟器级设置，重启 app 不丢）
sim ui "$DEVICE" appearance dark >/dev/null 2>&1 || log "[dark] WARN set dark failed"
sleep 1.5
goto_tab focus    && shot_file "$OUT_DIR/11-home-dark.png"     && record "$OUT_DIR/11-home-dark.png" 11-home-dark.png
goto_tab tasks    && shot_file "$OUT_DIR/12-tasks-dark.png"    && record "$OUT_DIR/12-tasks-dark.png" 12-tasks-dark.png
goto_tab stats    && shot_file "$OUT_DIR/13-stats-dark.png"    && record "$OUT_DIR/13-stats-dark.png" 13-stats-dark.png
goto_tab targets  && shot_file "$OUT_DIR/14-targets-dark.png"  && record "$OUT_DIR/14-targets-dark.png" 14-targets-dark.png
goto_tab settings && shot_file "$OUT_DIR/15-settings-dark.png" && record "$OUT_DIR/15-settings-dark.png" 15-settings-dark.png
sim ui "$DEVICE" appearance light >/dev/null 2>&1 || true

# 4) 巡内 sanity：全部截图同一 md5 = 导航失败，大声报警
UNIQ=$(for f in "$OUT_DIR"/*.png; do md5 -q "$f" 2>/dev/null || md5sum "$f" | awk '{print $1}'; done | sort -u | wc -l | tr -d ' ')
TOTAL=$(ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
log "[summary] shots=$TOTAL unique=$UNIQ"
if [ "$TOTAL" -gt 0 ] && [ "$UNIQ" -le 2 ]; then
  log "[summary] !! shots nearly all identical — navigation failed; check FF_TAB wiring"
fi
log "[tour] done"
exit 0
