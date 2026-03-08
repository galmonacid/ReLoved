#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app"
CONTROL_BASE_URL="http://127.0.0.1:${E2E_CONTROL_PORT:-8787}"
CONTROL_LOG="$(mktemp -t reloved-e2e-control.XXXXXX.log)"
CHROMEDRIVER_LOG="$(mktemp -t reloved-e2e-chromedriver.XXXXXX.log)"
CHROME_PROFILE_DIR="$(mktemp -d -t reloved-e2e-chrome.XXXXXX)"

cleanup_stale_processes() {
  pkill -f chromedriver 2>/dev/null || true
  pkill -f "flutter drive" 2>/dev/null || true
  pkill -f "flutter_tester" 2>/dev/null || true
  pkill -f "dart.*dwds" 2>/dev/null || true
  pkill -f "dart.*devtools" 2>/dev/null || true
  pkill -f "Google Chrome for Testing" 2>/dev/null || true
  rm -rf "$APP_DIR/build"
}

cleanup() {
  if [ -n "${DRIVE_PID:-}" ] && kill -0 "$DRIVE_PID" 2>/dev/null; then
    kill "$DRIVE_PID" 2>/dev/null || true
  fi
  if [ -n "${CONTROL_PID:-}" ] && kill -0 "$CONTROL_PID" 2>/dev/null; then
    kill "$CONTROL_PID" 2>/dev/null || true
  fi
  if [ -n "${CHROMEDRIVER_PID:-}" ] && kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
  rm -rf "$CHROME_PROFILE_DIR"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

cleanup_stale_processes

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "chromedriver is required in PATH to run Flutter web integration tests." >&2
  echo "Install it locally and rerun scripts/e2e/run_chat_e2e.sh." >&2
  exit 1
fi

echo "Using $(chromedriver --version)"
echo "Chromedriver log: $CHROMEDRIVER_LOG"
echo "Control server log: $CONTROL_LOG"
echo "Chrome profile dir: $CHROME_PROFILE_DIR"

if [ -n "${CHROME_BINARY:-}" ]; then
  echo "Using chrome binary: $CHROME_BINARY"
  "$CHROME_BINARY" --version || true
fi

node "$ROOT_DIR/scripts/e2e/control_server.cjs" >"$CONTROL_LOG" 2>&1 &
CONTROL_PID=$!

chromedriver \
  --port="${CHROMEDRIVER_PORT:-4444}" \
  --allowed-origins="*" \
  >"$CHROMEDRIVER_LOG" 2>&1 &
CHROMEDRIVER_PID=$!

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

for _ in $(seq 1 40); do
  if curl -sS "http://127.0.0.1:${CHROMEDRIVER_PORT:-4444}/status" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! curl -sS "http://127.0.0.1:${CHROMEDRIVER_PORT:-4444}/status" >/dev/null 2>&1; then
  echo "chromedriver did not become ready. Log:" >&2
  cat "$CHROMEDRIVER_LOG" >&2
  exit 1
fi

HEADLESS_FLAG="--no-headless"
if [ "${E2E_HEADLESS:-0}" = "1" ]; then
  HEADLESS_FLAG="--headless"
fi

BUILD_MODE="${E2E_BUILD_MODE:-profile}"
BUILD_MODE_FLAG=()
DEBUG_ONLY_FLAGS=()

case "$BUILD_MODE" in
  debug)
    DEBUG_ONLY_FLAGS+=(--no-start-paused --no-dds)
    ;;
  profile)
    BUILD_MODE_FLAG+=(--profile)
    ;;
  release)
    BUILD_MODE_FLAG+=(--release)
    ;;
  *)
    echo "Unsupported E2E_BUILD_MODE: $BUILD_MODE" >&2
    echo "Use one of: debug, profile, release." >&2
    exit 1
    ;;
esac

TARGETS=(
  "integration_test/chat_send_message_test.dart"
  "integration_test/chat_receive_live_message_test.dart"
  "integration_test/chat_inbox_preview_test.dart"
  "integration_test/auth_search_smoke_test.dart"
)

if [ -n "${E2E_TARGETS:-}" ]; then
  IFS=',' read -r -a TARGETS <<<"${E2E_TARGETS}"
fi

cd "$APP_DIR"
for target in "${TARGETS[@]}"; do
  echo "==> Running $target"
  DRIVE_CMD=(
    flutter
    drive
    "${BUILD_MODE_FLAG[@]}"
    --driver=test_driver/integration_test.dart
    --target="$target"
    -d
    "${E2E_DEVICE:-chrome}"
    --browser-name=chrome
    "$HEADLESS_FLAG"
    --no-web-resources-cdn
    --driver-port="${CHROMEDRIVER_PORT:-4444}"
    --browser-dimension="1440x1100"
    --web-hostname=127.0.0.1
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE_DIR"
    --web-browser-flag=--no-first-run
    --web-browser-flag=--no-default-browser-check
    --web-browser-flag=--disable-search-engine-choice-screen
    --no-pub
    --dart-define=USE_FIREBASE_EMULATORS=true
    --dart-define=E2E_PROJECT_ID="${E2E_PROJECT_ID:-demo-reloved-e2e}"
    --dart-define=AUTH_EMULATOR_HOST=127.0.0.1
    --dart-define=AUTH_EMULATOR_PORT=9099
    --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1
    --dart-define=FIRESTORE_EMULATOR_PORT=8080
    --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1
    --dart-define=FUNCTIONS_EMULATOR_PORT=5001
    --dart-define=CHAT_FUNCTIONS_REGION="${E2E_CHAT_FUNCTIONS_REGION:-us-central1}"
    --dart-define=STORAGE_EMULATOR_HOST=127.0.0.1
    --dart-define=STORAGE_EMULATOR_PORT=9199
    --dart-define=E2E_CONTROL_BASE_URL="$CONTROL_BASE_URL"
    --dart-define=E2E_FIXED_POSTCODE="MK9 3QA"
  )

  if [ "${#DEBUG_ONLY_FLAGS[@]}" -gt 0 ]; then
    DRIVE_CMD+=("${DEBUG_ONLY_FLAGS[@]}")
  fi

  if [ -n "${CHROME_BINARY:-}" ]; then
    DRIVE_CMD+=(--chrome-binary="$CHROME_BINARY")
  fi

  if [ "${E2E_VERBOSE:-0}" = "1" ]; then
    DRIVE_CMD=(flutter -v "${DRIVE_CMD[@]:1}")
  fi

  "${DRIVE_CMD[@]}" &
  DRIVE_PID=$!
  wait "$DRIVE_PID"
  DRIVE_PID=""
done
