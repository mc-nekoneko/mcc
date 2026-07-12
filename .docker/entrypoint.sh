#!/usr/bin/env bash
set -euo pipefail

cd "${HOME:-/home/minecraft}"

SERVER_MEMORY=${SERVER_MEMORY:-4G}
SERVER_JARFILE=${SERVER_JARFILE:-/opt/papermc/server.jar}
JVM_FLAGS=${JVM_FLAGS:-}
SERVER_ARGS=${SERVER_ARGS:-}

[[ "$SERVER_MEMORY" =~ ^[0-9]+[KMGkmg]?$ ]] || { echo "Invalid SERVER_MEMORY: $SERVER_MEMORY" >&2; exit 64; }
[[ -r "$SERVER_JARFILE" ]] || { echo "Server jar is not readable: $SERVER_JARFILE" >&2; exit 66; }

java -version
printf 'Starting %s with Java; memory=%s\n' "$SERVER_JARFILE" "$SERVER_MEMORY"
command=(java "-Xms${SERVER_MEMORY}" "-Xmx${SERVER_MEMORY}")
if [[ -n "$JVM_FLAGS" ]]; then
  read -r -a jvm_flags <<< "$JVM_FLAGS"
  command+=("${jvm_flags[@]}")
fi
command+=(-jar "$SERVER_JARFILE")
if [[ -n "$SERVER_ARGS" ]]; then
  read -r -a server_args <<< "$SERVER_ARGS"
  command+=("${server_args[@]}")
fi
exec "${command[@]}"
