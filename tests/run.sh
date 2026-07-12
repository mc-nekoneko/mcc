#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURES="$ROOT/tests/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok() { printf 'ok - %s\n' "$1"; pass=$((pass + 1)); }
not_ok() { printf 'not ok - %s\n' "$1" >&2; fail=$((fail + 1)); }
assert_eq() { [[ "$1" == "$2" ]] || { printf 'expected <%s>, got <%s>\n' "$2" "$1" >&2; return 1; }; }
assert_fail() { if "$@" >"$TMP/fail.out" 2>"$TMP/fail.err"; then cat "$TMP/fail.out" "$TMP/fail.err" >&2; return 1; fi; }

export FAKE_CURL_LOG="$TMP/curl.log"
export FAKE_CURL_FIXTURES="$FIXTURES"
export CURL_BIN="$ROOT/tests/fake-curl.sh"
API="https://fill.test/v3"

test_v2_410_and_user_agent() {
  : > "$FAKE_CURL_LOG"
  assert_fail env PAPERMC_API_BASE=https://api.papermc.io/v2 "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track current --version 3.5.1 --build 615
  grep -q 'HTTP 410' "$TMP/fail.err"

  : > "$FAKE_CURL_LOG"
  PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track current --version 3.5.1 --build 615 > "$TMP/metadata.json"
  grep -q -- '-A mc-nekoneko/mcc/' "$FAKE_CURL_LOG"
  ! grep -q '/v2/' "$FAKE_CURL_LOG"
}

test_exact_velocity_metadata() {
  PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track current --version 3.5.1 --build 615 > "$TMP/metadata.json"
  assert_eq "$(jq -r .build "$TMP/metadata.json")" "615"
  assert_eq "$(jq -r .java "$TMP/metadata.json")" "21"
  assert_eq "$(jq -r .channel "$TMP/metadata.json")" "RECOMMENDED"
  assert_eq "$(jq -r .canonical_tag "$TMP/metadata.json")" "3.5.1-b615-j21-r1"
  [[ "$(jq -r .java_image "$TMP/metadata.json")" == *'@sha256:'* ]]
  assert_eq "$(jq -r '.compatibility_tags[0]' "$TMP/metadata.json")" "3.5.1-615"
  assert_eq "$(jq -r '.moving_tags | join(",")' "$TMP/metadata.json")" "current,latest,3.5.1"
}

test_channel_selection_and_empty_builds() {
  PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track current --version 3.5.1 > "$TMP/selected.json"
  assert_eq "$(jq -r .build "$TMP/selected.json")" "615"
  assert_fail env PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track preview --version 4.0.0
  grep -qi 'no builds' "$TMP/fail.err"
  assert_fail env PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track custom --version 3.5.1 --build 614
  grep -qi 'channel' "$TMP/fail.err"
}

test_unsupported_requires_allowlist() {
  assert_fail env PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project paper --track custom --version 9.9.9 --build 1
  grep -qi 'allowlist' "$TMP/fail.err"

  PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project paper --track legacy --version 1.12.2 --build 1620 --jre 11 > "$TMP/legacy.json"
  assert_eq "$(jq -r .canonical_tag "$TMP/legacy.json")" "1.12.2-b1620-j11-r1"
}

test_custom_does_not_move_latest() {
  PAPERMC_API_BASE=$API "$ROOT/scripts/resolve-papermc.sh" \
    --project velocity --track custom --version 3.5.1 --build 615 > "$TMP/custom.json"
  assert_eq "$(jq -r '.moving_tags | length' "$TMP/custom.json")" "0"
  assert_eq "$(jq -r '.compatibility_tags[0]' "$TMP/custom.json")" "3.5.1-615"
}

test_checksum_success_and_failure() {
  "$ROOT/scripts/download-papermc.sh" \
    https://downloads.test/velocity-3.5.1-615.jar \
    00124c4d34134e438faf2cfa2fcc436a26ac3e0142c6607831c50c0e7edab66d \
    "$TMP/server.jar"
  [[ -s "$TMP/server.jar" ]]
  assert_fail "$ROOT/scripts/download-papermc.sh" \
    https://downloads.test/bad.jar \
    00124c4d34134e438faf2cfa2fcc436a26ac3e0142c6607831c50c0e7edab66d \
    "$TMP/bad.jar"
  [[ ! -e "$TMP/bad.jar" ]]
}

test_entrypoint_exec_and_term() {
  mkdir -p "$TMP/bin" "$TMP/home"
  cc "$ROOT/tests/fake-java.c" -o "$TMP/bin/java"
  : > "$TMP/java.log"
  PATH="$TMP/bin:$PATH" JAVA_TEST_LOG="$TMP/java.log" HOME="$TMP/home" \
    SERVER_MEMORY=128M SERVER_JARFILE="$TMP/server.jar" SERVER_ARGS="--test-mode" \
    "$ROOT/.docker/entrypoint.sh" &
  pid=$!
  for _ in {1..50}; do grep -q started "$TMP/java.log" && break; sleep 0.05; done
  kill -TERM "$pid"
  wait "$pid"
  grep -q '^term ' "$TMP/java.log"
  assert_eq "$(awk '/^started / {print $2}' "$TMP/java.log")" "$pid"
}

tests=(
  test_v2_410_and_user_agent
  test_exact_velocity_metadata
  test_channel_selection_and_empty_builds
  test_unsupported_requires_allowlist
  test_custom_does_not_move_latest
  test_checksum_success_and_failure
  test_entrypoint_exec_and_term
)

for test_name in "${tests[@]}"; do
  if "$test_name"; then ok "$test_name"; else not_ok "$test_name"; fi
done

printf '%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
