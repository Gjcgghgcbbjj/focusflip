#!/bin/bash
# =============================================================================
# FocusFlip UI 截图巡游（skill §六 CI 截图验证闭环）
#
# 用法（由 build-ipa.yml 调用，也可本地对已 boot 的模拟器手动跑）:
#   DEVICE=<udid> OUT_DIR=build/tour PREV_DIR=tour-prev ./Scripts/ui-tour.sh
#
# 流程: 权限弹窗处理 → 亮色五 tab 巡游(URL scheme 导航) → 键盘态(尽力)
#       → 暗色一轮 → md5 对比上一 run 写 tour.log → 存档供缓存
#
# 纪律: 巡游是证据不是门禁——单点失败记 SKIP/MISSING 继续，不 fail 构建。
#       坐标一律用屏幕百分比，换机型不失效。
# =============================================================================
set -uo pipefail

DEVICE="${DEVICE:?need DEVICE udid}"
BUNDLE_ID="${BUNDLE_ID:-com.focusflip.app}"
OUT_DIR="${OUT_DIR:-build/tour}"
PREV_DIR="${PREV_DIR:-tour-prev}"
mkdir -p "$OUT_DIR" "$PREV_DIR"
LOG="$OUT_DIR/tour.log"
: > "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

sim() { xcrun simctl "$@"; }

# ---------------------------------------------------------------- screenshot
SHOT_TMP="$(mktemp /tmp/ff-shot-XXXXXX).png"

shot_file() { # $1 = dest path
  sim io "$DEVICE" screenshot "$1" >/dev/null 2>&1
}

screen_points() { # echo "WxH" in points
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

# ---------------------------------------------------------------- tap 后端链
# 降级链: simctl ui tap → idb (skill §六)。坐标一律 points。
TAP_BACKEND=""
PW=390; PH=844
if PTS=$(screen_points); then
  PW="${PTS%x*}"; PH="${PTS#*x}"
fi
log "[tour] device points: ${PW}x${PH}"

detect_tap_backend() {
  if sim ui "$DEVICE" tap 100 100 >/dev/null 2>&1; then
    TAP_BACKEND="simctl"; return 0
  fi
  if command -v idb >/dev/null 2>&1; then
    TAP_BACKEND="idb"; return 0
  fi
  log "[tour] installing idb (fallback tap backend)..."
  if brew install idb-companion >/dev/null 2>&1 \
     && python3 -m pip install --break-system-packages -q fb-idb >/dev/null 2>&1; then
    TAP_BACKEND="idb-shim"; return 0
  fi
  { echo "--- idb-companion install tail ---"; tail -5 < <(brew install idb-companion 2>&1) || true; } >> "$LOG"
  TAP_BACKEND="none"
  log "[tap] WARN no tap backend available; navigation falls back to URL scheme only"
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

tap_pct() { # $1=x% $2=y%  (0-100, 屏幕百分比换机型不失效)
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
_last_nav_md5=""
goto_tab() { # $1=tab名
  sim openurl "$DEVICE" "focusflip://tab/$1" >/dev/null 2>&1 || log "[nav] WARN openurl tab/$1 failed"
  sleep 1.4
  # 自愈：warm openurl 被 modal 弹窗吞掉时不换页 → terminate 冷启动带 URL 再试
  local f md5; f="$(mktemp /tmp/ff-nav-XXXXXX).png"
  sim io "$DEVICE" screenshot "$f" >/dev/null 2>&1
  md5=$(md5 -q "$f" 2>/dev/null || md5sum "$f" | awk '{print $1}')
  rm -f "$f"
  if [ -n "$_last_nav_md5" ] && [ "$md5" = "$_last_nav_md5" ]; then
    log "[nav] warm openurl no-op (screen unchanged) → cold relaunch with URL"
    sim terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 1
    sim openurl "$DEVICE" "focusflip://tab/$1" >/dev/null 2>&1 || true
    sleep 3
  fi
  _last_nav_md5="$md5"
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
detect_tap_backend
log "[tour] tap backend: $TAP_BACKEND"

# 1) 权限弹窗处理：FF_UI_TOUR=1 时 app 不请求权限，弹窗根本不出现（构造性避开）；
#    否则点 Allow 在 (69.5%, 56.8%)，无弹窗时该点为环右侧空白，无害
sleep 2
if [ "${FF_UI_TOUR:-}" = "1" ] || [ "${SIMCTL_CHILD_FF_UI_TOUR:-}" = "1" ]; then
  log "[alert] FF_UI_TOUR active — permission alert suppressed in app, skip tap"
elif ! tap_pct 69 57; then
  log "[alert] WARN tap unavailable, alert may persist in shots"
fi
sleep 1.2

# 2) 亮色巡游
goto_tab focus   && shot_file "$OUT_DIR/01-home.png"     && record "$OUT_DIR/01-home.png" 01-home.png
goto_tab tasks   && shot_file "$OUT_DIR/02-tasks.png"    && record "$OUT_DIR/02-tasks.png" 02-tasks.png
goto_tab stats   && shot_file "$OUT_DIR/03-stats.png"    && record "$OUT_DIR/03-stats.png" 03-stats.png
goto_tab targets && shot_file "$OUT_DIR/04-targets.png"  && record "$OUT_DIR/04-targets.png" 04-targets.png
goto_tab settings && shot_file "$OUT_DIR/05-settings.png" && record "$OUT_DIR/05-settings.png" 05-settings.png

# 3) 键盘态（尽力）：任务页顶部输入框；坐标下一轮按实拍修
goto_tab tasks
if tap_pct 50 17; then
  sleep 1.5
  shot_file "$OUT_DIR/06-tasks-keyboard.png"
  record "$OUT_DIR/06-tasks-keyboard.png" 06-tasks-keyboard.png
  tap_pct 50 60 || true   # 点空白处收键盘
  sleep 0.6
else
  log "[MISSING] 06-tasks-keyboard.png (no tap backend)"
fi

# 4) 暗色一轮（skill: simctl ui appearance dark 再截一轮）
sim ui "$DEVICE" appearance dark >/dev/null 2>&1 || log "[dark] WARN set dark failed"
sleep 1.5
goto_tab focus    && shot_file "$OUT_DIR/11-home-dark.png"     && record "$OUT_DIR/11-home-dark.png" 11-home-dark.png
goto_tab tasks    && shot_file "$OUT_DIR/12-tasks-dark.png"    && record "$OUT_DIR/12-tasks-dark.png" 12-tasks-dark.png
goto_tab stats    && shot_file "$OUT_DIR/13-stats-dark.png"    && record "$OUT_DIR/13-stats-dark.png" 13-stats-dark.png
goto_tab targets  && shot_file "$OUT_DIR/14-targets-dark.png"  && record "$OUT_DIR/14-targets-dark.png" 14-targets-dark.png
goto_tab settings && shot_file "$OUT_DIR/15-settings-dark.png" && record "$OUT_DIR/15-settings-dark.png" 15-settings-dark.png
sim ui "$DEVICE" appearance light >/dev/null 2>&1 || true

# 5) 巡内 sanity：全部截图同一 md5 = 导航失败，大声报警
UNIQ=$(for f in "$OUT_DIR"/*.png; do md5 -q "$f" 2>/dev/null || md5sum "$f" | awk '{print $1}'; done | sort -u | wc -l | tr -d ' ')
TOTAL=$(ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
log "[summary] shots=$TOTAL unique=$UNIQ backend=$TAP_BACKEND"
if [ "$TOTAL" -gt 0 ] && [ "$UNIQ" -eq 1 ]; then
  log "[summary] !! ALL SHOTS IDENTICAL — navigation almost certainly failed; fix tap backend or URL scheme"
fi
rm -f "$SHOT_TMP"
log "[tour] done"
exit 0
