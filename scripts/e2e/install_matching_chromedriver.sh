#!/usr/bin/env bash
set -euo pipefail

chrome_binary="${1:-${CHROME_BINARY:-}}"
if [ -z "$chrome_binary" ]; then
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chrome_binary="$(command -v "$candidate")"
      break
    fi
  done
fi

if [ -z "$chrome_binary" ] || [ ! -x "$chrome_binary" ]; then
  echo "Chrome binary not found. Pass the browser path as the first argument or set CHROME_BINARY." >&2
  exit 1
fi

chrome_version="$("$chrome_binary" --version | grep -Eo '[0-9]+(\.[0-9]+){3}' | head -n 1)"
if [ -z "$chrome_version" ]; then
  echo "Unable to parse Chrome version from: $("$chrome_binary" --version)" >&2
  exit 1
fi

chrome_build="${chrome_version%.*}"
chrome_major="${chrome_version%%.*}"

default_platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo "linux64" ;;
    Darwin-arm64) echo "mac-arm64" ;;
    Darwin-x86_64) echo "mac-x64" ;;
    *)
      echo "Unsupported platform: $(uname -s)-$(uname -m). Set CHROMEDRIVER_PLATFORM explicitly." >&2
      exit 1
      ;;
  esac
}

platform="${CHROMEDRIVER_PLATFORM:-$(default_platform)}"
install_dir="${CHROMEDRIVER_INSTALL_DIR:-${RUNNER_TEMP:-/tmp}/reloved-chromedriver}"
metadata_file="$(mktemp)"
zip_file="$(mktemp -t reloved-chromedriver.XXXXXX.zip)"
extract_dir="$(mktemp -d)"

cleanup() {
  rm -f "$metadata_file" "$zip_file"
  rm -rf "$extract_dir"
}
trap cleanup EXIT

find_driver_url() {
  local metadata_url="$1"
  local node_script="$2"

  curl -fsSL "$metadata_url" -o "$metadata_file"
  node -e "$node_script" "$metadata_file" "$chrome_build" "$chrome_major" "$platform"
}

driver_url="$(
  find_driver_url \
    "https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json" \
    'const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const build = process.argv[2];
const platform = process.argv[4];
const entry = data.builds && data.builds[build];
const download = entry && entry.downloads && entry.downloads.chromedriver &&
  entry.downloads.chromedriver.find((item) => item.platform === platform);
if (!download) process.exit(1);
console.log(download.url);' \
  || true
)"

if [ -z "$driver_url" ]; then
  driver_url="$(
    find_driver_url \
      "https://googlechromelabs.github.io/chrome-for-testing/latest-versions-per-milestone-with-downloads.json" \
      'const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const major = process.argv[3];
const platform = process.argv[4];
const entry = data.milestones && data.milestones[major];
const download = entry && entry.downloads && entry.downloads.chromedriver &&
  entry.downloads.chromedriver.find((item) => item.platform === platform);
if (!download) process.exit(1);
console.log(download.url);' \
  )"
fi

mkdir -p "$install_dir"
curl -fsSL "$driver_url" -o "$zip_file"
unzip -q "$zip_file" -d "$extract_dir"
driver_path="$(find "$extract_dir" -type f -name chromedriver | head -n 1)"
if [ -z "$driver_path" ]; then
  echo "Downloaded ChromeDriver archive did not contain a chromedriver binary." >&2
  exit 1
fi

cp "$driver_path" "$install_dir/chromedriver"
chmod +x "$install_dir/chromedriver"

echo "Installed $("$install_dir/chromedriver" --version) for Chrome $chrome_version"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$install_dir" >> "$GITHUB_PATH"
fi
