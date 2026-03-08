#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app"
CONTROL_BASE_URL="http://127.0.0.1:${E2E_CONTROL_PORT:-8787}"
PROJECT_ID="${E2E_FIREBASE_PROJECT_ID:-${GCLOUD_PROJECT:-reloved-greenhilledge}}"
TARGETS="${E2E_TARGETS:-integration_test/chat_open_performance_test.dart}"
CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"
CHROME_PROFILE_DIR="$(mktemp -d -t reloved-remote-e2e-chrome.XXXXXX)"
CONTROL_LOG="$(mktemp -t reloved-remote-e2e-control.XXXXXX.log)"
CHROMEDRIVER_LOG="$(mktemp -t reloved-remote-e2e-chromedriver.XXXXXX.log)"
DRIVE_LOG="$(mktemp -t reloved-remote-e2e-drive.XXXXXX.log)"

cleanup() {
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

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "chromedriver is required in PATH." >&2
  exit 1
fi

if [ "$PROJECT_ID" = "reloved-greenhilledge" ] && [ "${E2E_ALLOW_PROD_PROJECT:-0}" != "1" ]; then
  echo "Refusing to run against production project '$PROJECT_ID'." >&2
  echo "Set E2E_ALLOW_PROD_PROJECT=1 to confirm." >&2
  exit 1
fi

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  ADC_DEFAULT="$HOME/.config/gcloud/application_default_credentials.json"
  ACTIVE_ACCOUNT="$(
    /usr/local/share/google-cloud-sdk/bin/gcloud config get-value account 2>/dev/null | tr -d '\r'
  )"
  ADC_LEGACY="$HOME/.config/gcloud/legacy_credentials/${ACTIVE_ACCOUNT}/adc.json"
  if [ -n "$ACTIVE_ACCOUNT" ] && [ "$ACTIVE_ACCOUNT" != "(unset)" ] && [ -f "$ADC_LEGACY" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$ADC_LEGACY"
  elif [ -f "$ADC_DEFAULT" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$ADC_DEFAULT"
  fi
fi

if ! /usr/local/share/google-cloud-sdk/bin/gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Application default credentials are invalid." >&2
  echo "Run: gcloud auth application-default login" >&2
  exit 1
fi

echo "Remote perf project: $PROJECT_ID"
echo "ADC file: ${GOOGLE_APPLICATION_CREDENTIALS:-<application-default>}"
echo "Control server log: $CONTROL_LOG"
echo "Chromedriver log: $CHROMEDRIVER_LOG"
echo "Flutter drive log: $DRIVE_LOG"

cd "$APP_DIR"
flutter pub get

E2E_CONTROL_USE_EMULATORS=0 \
E2E_PROJECT_ID="$PROJECT_ID" \
E2E_CONTROL_PORT="${E2E_CONTROL_PORT:-8787}" \
node "$ROOT_DIR/scripts/e2e/control_server.cjs" >"$CONTROL_LOG" 2>&1 &
CONTROL_PID=$!

for _ in $(seq 1 60); do
  if curl -sS "$CONTROL_BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done
if ! curl -sS "$CONTROL_BASE_URL/health" >/dev/null 2>&1; then
  echo "Control server failed to start. Log:" >&2
  cat "$CONTROL_LOG" >&2
  exit 1
fi

chromedriver \
  --port="$CHROMEDRIVER_PORT" \
  --allowed-origins="*" \
  >"$CHROMEDRIVER_LOG" 2>&1 &
CHROMEDRIVER_PID=$!

for _ in $(seq 1 40); do
  if curl -sS "http://127.0.0.1:${CHROMEDRIVER_PORT}/status" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done
if ! curl -sS "http://127.0.0.1:${CHROMEDRIVER_PORT}/status" >/dev/null 2>&1; then
  echo "chromedriver failed to start. Log:" >&2
  cat "$CHROMEDRIVER_LOG" >&2
  exit 1
fi

HEADLESS_FLAG="--headless"
if [ "${E2E_HEADLESS:-1}" = "0" ]; then
  HEADLESS_FLAG="--no-headless"
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
    exit 1
    ;;
esac

IFS=',' read -r -a TARGET_LIST <<<"$TARGETS"
for target in "${TARGET_LIST[@]}"; do
  echo "==> Running remote perf target $target"
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
    --driver-port="$CHROMEDRIVER_PORT"
    --browser-dimension="1440x1100"
    --web-hostname=127.0.0.1
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE_DIR"
    --web-browser-flag=--no-first-run
    --web-browser-flag=--no-default-browser-check
    --web-browser-flag=--disable-search-engine-choice-screen
    --no-pub
    --dart-define=USE_FIREBASE_EMULATORS=false
    --dart-define=E2E_PROJECT_ID="$PROJECT_ID"
    --dart-define=E2E_CONTROL_BASE_URL="$CONTROL_BASE_URL"
    --dart-define=E2E_FIXED_POSTCODE="${E2E_FIXED_POSTCODE:-MK9 3QA}"
    --dart-define=E2E_DISABLE_ANALYTICS=true
    --dart-define=E2E_DISABLE_FIREBASE_SIDE_EFFECTS=true
    --dart-define=E2E_CHAT_OPEN_BUDGET_MS="${E2E_CHAT_OPEN_BUDGET_MS:-2500}"
  )
  if [ "${#DEBUG_ONLY_FLAGS[@]}" -gt 0 ]; then
    DRIVE_CMD+=("${DEBUG_ONLY_FLAGS[@]}")
  fi
  if [ -n "${CHROME_BINARY:-}" ]; then
    DRIVE_CMD+=(--chrome-binary="$CHROME_BINARY")
  fi

  set +e
  "${DRIVE_CMD[@]}" 2>&1 | tee "$DRIVE_LOG"
  DRIVE_STATUS=${PIPESTATUS[0]}
  set -e

  elapsed_ms="$(grep -o 'chat_open_perf_elapsed_ms":[0-9]\+' "$DRIVE_LOG" | tail -1 | cut -d: -f2 || true)"
  budget_ms="$(grep -o 'chat_open_perf_budget_ms":[0-9]\+' "$DRIVE_LOG" | tail -1 | cut -d: -f2 || true)"
  if [ -n "$elapsed_ms" ] && [ -n "$budget_ms" ]; then
    echo "Remote chat_open_perf: ${elapsed_ms}ms (budget ${budget_ms}ms)"
  fi

  if [ "$DRIVE_STATUS" -ne 0 ]; then
    exit "$DRIVE_STATUS"
  fi
done
