#!/usr/bin/env bash
set -euo pipefail

log=${FAKE_CURL_LOG:?}
fixtures=${FAKE_CURL_FIXTURES:?}
printf '%q ' "$@" >> "$log"
printf '\n' >> "$log"

output=
url=
user_agent=
while (($#)); do
  case "$1" in
    -A|--user-agent)
      user_agent=${2:-}
      shift 2
      ;;
    -o|--output)
      output=${2:-}
      shift 2
      ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done

[[ -n "$user_agent" ]] || { echo "missing User-Agent" >&2; exit 22; }
[[ "$user_agent" == *"mc-nekoneko/mcc"* ]] || { echo "non-identifying User-Agent" >&2; exit 22; }

if [[ "$url" == *"/v2/"* || "$url" == *"api.papermc.io/v2"* ]]; then
  echo "HTTP 410" >&2
  exit 22
fi

case "$url" in
  */projects/velocity/versions/3.5.1) file=velocity-3.5.1.json ;;
  */projects/velocity/versions/3.5.1/builds/615) file=velocity-3.5.1-build-615.json ;;
  */projects/velocity/versions/3.5.1/builds/614) file=velocity-3.5.1-build-614.json ;;
  */projects/velocity/versions/3.5.1/builds/613) file=velocity-3.5.1-build-613.json ;;
  */projects/velocity/versions/4.0.0) file=velocity-4.0.0.json ;;
  */projects/paper/versions/1.12.2) file=paper-1.12.2.json ;;
  */projects/paper/versions/1.12.2/builds/1620) file=paper-1.12.2-build-1620.json ;;
  */projects/paper/versions/9.9.9) file=unsupported.json ;;
  */projects/paper/versions/9.9.9/builds/1) file=unsupported-build-1.json ;;
  https://downloads.test/velocity-3.5.1-615.jar) printf 'velocity fixture jar\n' > "$output"; exit 0 ;;
  https://downloads.test/paper-1.12.2-1620.jar) printf 'paper fixture jar\n' > "$output"; exit 0 ;;
  https://downloads.test/bad.jar) printf 'tampered jar\n' > "$output"; exit 0 ;;
  *) echo "fixture not found: $url" >&2; exit 22 ;;
esac

if [[ -n "$output" ]]; then
  cp "$fixtures/$file" "$output"
else
  cat "$fixtures/$file"
fi
