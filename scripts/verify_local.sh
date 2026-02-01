#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Note: add rules/function tests here once implemented.
