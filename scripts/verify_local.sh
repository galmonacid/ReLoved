#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prefer local JDK 21 if available (for Firebase emulators).
LOCAL_JDK_DIR="$HOME/.local/jdk-21/Contents/Home"
if [ -d "$LOCAL_JDK_DIR" ]; then
  export JAVA_HOME="$LOCAL_JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

run_step() {
  echo "==> $*"
  "$@"
}

# Flutter app checks
pushd "$ROOT_DIR/app" >/dev/null
run_step flutter --version
run_step flutter pub get
run_step flutter analyze
run_step flutter test
popd >/dev/null

# Backend functions build check
run_step npm --prefix "$ROOT_DIR/backend/functions" ci
run_step npm --prefix "$ROOT_DIR/backend/functions" run build
run_step npm --prefix "$ROOT_DIR/backend/functions" run test:functions

# Rules tests (requires emulators)
run_step npx firebase-tools emulators:exec --only firestore,storage \
  "npm --prefix $ROOT_DIR/backend/functions run test:rules"

# Integration flow tests (requires Firestore emulator)
run_step npx firebase-tools emulators:exec --only firestore,storage \
  "npm --prefix $ROOT_DIR/backend/functions run test:integration"

# Note: add rules/function tests here once implemented.
