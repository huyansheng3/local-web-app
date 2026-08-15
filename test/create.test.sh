#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CREATE_SCRIPT="$ROOT_DIR/create"

assert_contains() {
  local expected="$1"
  if ! grep -Fq "$expected" "$CREATE_SCRIPT"; then
    echo "Expected create to contain: $expected" >&2
    exit 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

bash -n "$CREATE_SCRIPT"
assert_equals 'local-web-app v1.2.1' "$("$CREATE_SCRIPT" --version)"

# A bare WKWebView treats file uploads as cancelled. The generated host must
# bridge HTML file inputs to an NSOpenPanel and retain that bridge as uiDelegate.
assert_contains 'final class WebViewCoordinator: NSObject, WKUIDelegate'
assert_contains 'runOpenPanelWith parameters: WKOpenPanelParameters'
assert_contains 'panel.allowsMultipleSelection = parameters.allowsMultipleSelection'
assert_contains 'panel.canChooseDirectories = parameters.allowsDirectories'
assert_contains 'wv.uiDelegate = context.coordinator'

echo "create tests passed"
