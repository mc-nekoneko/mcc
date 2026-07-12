#!/usr/bin/env bash
set -euo pipefail

url=${1:-}
expected_sha256=${2:-}
output=${3:-}
CURL=${CURL_BIN:-curl}
USER_AGENT=${PAPERMC_USER_AGENT:-mc-nekoneko/mcc/1.0\ \(+https://github.com/mc-nekoneko/mcc\)}

[[ "$url" == https://* ]] || { echo "error: HTTPS download URL is required" >&2; exit 1; }
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || { echo "error: valid SHA-256 is required" >&2; exit 1; }
[[ -n "$output" ]] || { echo "error: output path is required" >&2; exit 1; }

tmp="$output.part"
trap 'rm -f "$tmp"' EXIT
mkdir -p "$(dirname "$output")"
"$CURL" -fsSL -A "$USER_AGENT" "$url" -o "$tmp"

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256=$(sha256sum "$tmp" | awk '{print $1}')
else
  actual_sha256=$(shasum -a 256 "$tmp" | awk '{print $1}')
fi

if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "error: checksum mismatch: expected $expected_sha256, got $actual_sha256" >&2
  exit 1
fi

mv "$tmp" "$output"
trap - EXIT
