#!/usr/bin/env bash
# ============================================================
# LexRush Offline Result Retry Queue — Manual Verification Helper
# ============================================================
# Usage: source this file, then call individual functions.
# Requires: adb, curl, python3 in PATH; emulator-5554 running.
# ============================================================

set -euo pipefail

BACKEND="http://localhost:3000"
DEVICE="emulator-5554"
APP_PKG="com.example.lexrush"   # adjust if bundle ID differs
PREFS_KEY="lexrush.pending_results.v1"
USER_A_EMAIL="testuser_a@lexrush.test"
USER_A_PASS="TestPass123!"
USER_A_ID="c6387d69-a6fd-4b7c-af50-0db42401516f"
USER_B_EMAIL="testuser_b@lexrush.test"
USER_B_PASS="TestPass123!"
USER_B_ID="7d3726f3-2e0a-400d-a657-411bd2832e30"

# ---- Auth helpers -------------------------------------------------------
login() {
  local email="$1" pass="$2"
  curl -s -X POST "$BACKEND/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}"
}

get_token() { login "$1" "$2" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])"; }

# ---- Session helpers ----------------------------------------------------
create_session() {
  local token="$1" game_id="${2:-antonym_rush}"
  curl -s -X POST "$BACKEND/game-sessions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "{\"gameId\":\"$game_id\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['sessionId'])"
}

submit_result() {
  local token="$1" session_id="$2"
  curl -s -X POST "$BACKEND/game-sessions/$session_id/results" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d '{"score":700,"accuracy":0.8,"totalAttempts":10,"correctAnswers":8,"wrongAnswers":2,"missedAnswers":0,"wordsSolved":8,"bestCombo":4,"averageResponseTimeMs":2100}' \
    | python3 -m json.tool
}

get_progress() {
  local token="$1"
  curl -s -X GET "$BACKEND/me/progress" \
    -H "Authorization: Bearer $token" | python3 -m json.tool
}

# ---- Queue inspection via SharedPreferences -----------------------------
read_queue() {
  echo "=== Pending Queue Contents ==="
  adb -s "$DEVICE" shell "run-as $APP_PKG cat /data/data/$APP_PKG/shared_prefs/FlutterSharedPreferences.xml" 2>/dev/null \
    | python3 -c "
import sys, re, json, html
content = sys.stdin.read()
m = re.search(r'flutter\.lexrush\.pending_results\.v1[^>]*>([^<]+)<', content)
if not m:
    print('Queue: EMPTY (key not found)')
    sys.exit(0)
raw = html.unescape(m.group(1))
try:
    items = json.loads(raw)
    print(f'Queue items: {len(items)}')
    for i, item in enumerate(items):
        print(f'  [{i}] id={item.get(\"id\")} userId={item.get(\"userId\")} gameId={item.get(\"gameId\")} sessionId={item.get(\"sessionId\")}')
        req = item.get('request', {})
        print(f'       accuracy={req.get(\"accuracy\")} score={req.get(\"score\")} retryCount={item.get(\"retryCount\")}')
        answer_events = req.get('answerEvents')
        print(f'       answerEvents={answer_events}  (should be None/absent)')
except Exception as e:
    print(f'Parse error: {e}')
    print('Raw:', raw[:500])
" 2>&1 || echo "Could not read shared prefs (app may not be installed or pkg name wrong)"
}

clear_queue() {
  echo "=== Clearing Queue ==="
  adb -s "$DEVICE" shell "run-as $APP_PKG" <<'EOF' 2>/dev/null || echo "Could not clear (may need to use app UI)"
python3 -c "import os; f='/data/data/com.example.lexrush/shared_prefs/FlutterSharedPreferences.xml'; print('file exists' if os.path.exists(f) else 'not found')"
EOF
  echo "(Use adb shell am force-stop $APP_PKG && adb shell pm clear $APP_PKG to fully reset)"
}

inject_queue_item() {
  local user_id="$1" game_id="$2" session_id="$3"
  echo "=== Injecting Queue Item for user=$user_id session=$session_id ==="
  local now; now=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())")
  local item
  item=$(python3 -c "
import json
item = {
  'id': '${user_id}:${session_id}',
  'userId': '${user_id}',
  'gameId': '${game_id}',
  'sessionId': '${session_id}',
  'request': {
    'score': 700,
    'accuracy': 0.8,
    'totalAttempts': 10,
    'correctAnswers': 8,
    'wrongAnswers': 2,
    'missedAnswers': 0,
    'wordsSolved': 8,
    'bestCombo': 4,
    'averageResponseTimeMs': 2100
  },
  'createdAt': '${now}',
  'enqueuedAt': '${now}',
  'retryCount': 0
}
print(json.dumps([item]))
")
  echo "Item JSON: $item"
  echo ""
  echo "To inject, use adb shell content insert or write via the Flutter app itself."
  echo "The cleanest way is to kill the backend while the game completes, which triggers"
  echo "the app's own enqueue path. See the step-by-step guide below."
}

# ---- Backend kill/restart -----------------------------------------------
kill_backend() {
  echo "=== Killing Backend ==="
  pkill -f "nest start" 2>/dev/null || pkill -f "node.*dist/main" 2>/dev/null || true
  echo "Backend stopped. Verify with: curl http://localhost:3000/health"
}

start_backend() {
  echo "=== Starting Backend ==="
  (cd "$(dirname "$0")/../../../lexrush_backend" && npm run start:dev &>/tmp/lexrush_backend.log &)
  echo "Backend starting... watch /tmp/lexrush_backend.log"
  sleep 6
  curl -s "$BACKEND/health" || echo "Backend not yet ready"
}

check_backend() {
  curl -s "$BACKEND/health" && echo "" || echo "BACKEND_DOWN"
}

# ---- Flutter app control -----------------------------------------------
get_flutter_logs() {
  echo "=== Recent Flutter Logs (offline queue related) ==="
  adb -s "$DEVICE" logcat -d -t 200 2>/dev/null | grep -E "(BackendResultSync|OfflineResultRetry|PendingQueue|ProfileCubit|AuthCubit)" | tail -50
}

# ---- Step-by-step guide ------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  LexRush Offline Queue Manual Verification Helper Loaded     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Test Users:                                                  ║"
echo "║    User A: testuser_a@lexrush.test / TestPass123!            ║"
echo "║    User B: testuser_b@lexrush.test / TestPass123!            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Available commands:                                          ║"
echo "║    read_queue         — inspect SharedPreferences queue       ║"
echo "║    kill_backend       — stop NestJS                           ║"
echo "║    start_backend      — restart NestJS                        ║"
echo "║    check_backend      — health check                          ║"
echo "║    get_flutter_logs   — filter adb logcat for sync logs       ║"
echo "║    get_progress <tok> — get /me/progress                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
