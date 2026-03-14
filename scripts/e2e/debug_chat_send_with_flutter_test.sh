#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app"
CONTROL_BASE_URL="http://127.0.0.1:${E2E_CONTROL_PORT:-8787}"
CONTROL_LOG="$(mktemp -t reloved-e2e-control.XXXXXX.log)"

cleanup() {
  if [ -n "${CONTROL_PID:-}" ] && kill -0 "$CONTROL_PID" 2>/dev/null; then
    kill "$CONTROL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

LOCAL_JDK_DIR="$HOME/.local/jdk-21/Contents/Home"
if [ -d "$LOCAL_JDK_DIR" ]; then
  export JAVA_HOME="$LOCAL_JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

node "$ROOT_DIR/scripts/e2e/control_server.cjs" >"$CONTROL_LOG" 2>&1 &
CONTROL_PID=$!

for _ in $(seq 1 40); do
  if curl -sS "$CONTROL_BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! curl -sS "$CONTROL_BASE_URL/health" >/dev/null 2>&1; then
  echo "E2E control server did not become healthy. Log:" >&2
  cat "$CONTROL_LOG" >&2
  exit 1
fi

cd "$APP_DIR"
flutter test \
  integration_test/chat_send_message_test.dart \
  -d chrome \
  --no-pub \
  -r expanded \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=E2E_PROJECT_ID="${E2E_PROJECT_ID:-demo-reloved-e2e}" \
  --dart-define=AUTH_EMULATOR_HOST=127.0.0.1 \
  --dart-define=AUTH_EMULATOR_PORT=9099 \
  --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1 \
  --dart-define=FIRESTORE_EMULATOR_PORT=8080 \
  --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1 \
  --dart-define=FUNCTIONS_EMULATOR_PORT=5001 \
  --dart-define=STORAGE_EMULATOR_HOST=127.0.0.1 \
  --dart-define=STORAGE_EMULATOR_PORT=9199 \
  --dart-define=E2E_CONTROL_BASE_URL="$CONTROL_BASE_URL" \
  --dart-define=E2E_FIXED_POSTCODE="MK8 1AH"
