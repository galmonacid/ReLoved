#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app"
FUNCTIONS_DIR="$ROOT_DIR/backend/functions"
LOCK_DIR="${TMPDIR:-/tmp}/reloved-e2e-run.lock"

cleanup_stale_runners() {
  pkill -f "$ROOT_DIR/scripts/e2e/run_chat_e2e_inner.sh" 2>/dev/null || true
  pkill -f "$ROOT_DIR/scripts/e2e/control_server.cjs" 2>/dev/null || true
  pkill -f "firebase emulators:exec" 2>/dev/null || true
}

cleanup() {
  if [ -n "${EMULATORS_PID:-}" ] && kill -0 "$EMULATORS_PID" 2>/dev/null; then
    kill "$EMULATORS_PID" 2>/dev/null || true
  fi
  cleanup_stale_runners
  rm -rf "$LOCK_DIR"
}

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" >"$LOCK_DIR/pid"
    return
  fi

  if [ -f "$LOCK_DIR/pid" ]; then
    local existing_pid
    existing_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "Another E2E run is already active (pid $existing_pid)." >&2
      echo "Stop it before starting a new run." >&2
      exit 1
    fi
  fi

  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR"
  echo "$$" >"$LOCK_DIR/pid"
}

export E2E_PROJECT_ID="${E2E_PROJECT_ID:-demo-reloved-e2e}"
export E2E_DEVICE="${E2E_DEVICE:-chrome}"
export E2E_HEADLESS="${E2E_HEADLESS:-0}"
export E2E_BUILD_MODE="${E2E_BUILD_MODE:-profile}"
export E2E_CONTROL_PORT="${E2E_CONTROL_PORT:-8787}"
export CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"

cleanup_stale_runners
acquire_lock
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

LOCAL_JDK_DIR="$HOME/.local/jdk-21/Contents/Home"
if [ -d "$LOCAL_JDK_DIR" ]; then
  export JAVA_HOME="$LOCAL_JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

cd "$APP_DIR"
flutter pub get
cd "$FUNCTIONS_DIR"
npm run build

cd "$ROOT_DIR"
firebase emulators:exec \
  --project "$E2E_PROJECT_ID" \
  --only auth,firestore,functions,storage \
  "/bin/bash \"$ROOT_DIR/scripts/e2e/run_chat_e2e_inner.sh\"" &
EMULATORS_PID=$!
wait "$EMULATORS_PID"
EMULATORS_PID=""
