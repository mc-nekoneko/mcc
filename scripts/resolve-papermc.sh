#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TRACKS_FILE=${PAPERMC_TRACKS_FILE:-$ROOT/config/tracks.json}
API_BASE=${PAPERMC_API_BASE:-https://fill.papermc.io/v3}
CURL=${CURL_BIN:-curl}
USER_AGENT=${PAPERMC_USER_AGENT:-mc-nekoneko/mcc/1.0\ \(+https://github.com/mc-nekoneko/mcc\)}

project=
track=
version=
build=
jre=

usage() {
  cat <<'USAGE'
Usage: resolve-papermc.sh --project paper|velocity --track current|previous|legacy|preview|custom --version VERSION [--build BUILD] [--jre VERSION]
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --project) project=${2:-}; shift 2 ;;
    --track) track=${2:-}; shift 2 ;;
    --version) version=${2:-}; shift 2 ;;
    --build) build=${2:-}; shift 2 ;;
    --jre) jre=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$project" == paper || "$project" == velocity ]] || die "project must be paper or velocity"
case "$track" in current|previous|legacy|preview|custom) ;; *) die "invalid track: $track" ;; esac
[[ -n "$version" ]] || die "version is required; resolution never guesses a release line"
[[ -r "$TRACKS_FILE" ]] || die "track policy not readable: $TRACKS_FILE"
command -v jq >/dev/null || die "jq is required"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch_json() {
  local url=$1 output=$2
  "$CURL" -fsSL -A "$USER_AGENT" "$url" -o "$output"
  jq -e . "$output" >/dev/null || die "invalid JSON from $url"
}

version_url="$API_BASE/projects/$project/versions/$version"
fetch_json "$version_url" "$tmp/version.json"

resolved_version=$(jq -er '.version.id' "$tmp/version.json")
[[ "$resolved_version" == "$version" ]] || die "version response mismatch: expected $version, got $resolved_version"
support=$(jq -er '.version.support.status' "$tmp/version.json")
minimum_java=$(jq -er '.version.java.version.minimum' "$tmp/version.json")

policy=$(jq -c --arg project "$project" --arg track "$track" --arg version "$version" '
  .projects[$project][$track] // [] | map(select(.version == $version)) | first // empty
' "$TRACKS_FILE")

if [[ "$track" != custom && -z "$policy" ]]; then
  die "$project $version is not in the $track allowlist"
fi
if [[ "$support" != SUPPORTED && -z "$policy" ]]; then
  die "$project $version is unsupported and not in an explicit allowlist"
fi

policy_build=
policy_jre=
if [[ -n "$policy" ]]; then
  policy_build=$(jq -r '.build // empty' <<<"$policy")
  policy_jre=$(jq -r '.jre // empty' <<<"$policy")
fi

if [[ -n "$build" && -n "$policy_build" && "$build" != "$policy_build" ]]; then
  die "build $build is not in the $track allowlist for $project $version"
fi
if [[ -z "$build" && -n "$policy_build" ]]; then
  build=$policy_build
fi

channel_allowed() {
  case "$track:$1" in
    preview:ALPHA|preview:BETA|preview:EXPERIMENTAL|preview:RECOMMENDED|preview:STABLE) return 0 ;;
    current:RECOMMENDED|current:STABLE|previous:RECOMMENDED|previous:STABLE|legacy:RECOMMENDED|legacy:STABLE|custom:RECOMMENDED|custom:STABLE) return 0 ;;
    *) return 1 ;;
  esac
}

builds_count=$(jq -er '.builds | length' "$tmp/version.json")
((builds_count > 0)) || die "no builds are available for $project $version"

if [[ -n "$build" ]]; then
  jq -e --argjson build "$build" '.builds | index($build) != null' "$tmp/version.json" >/dev/null \
    || die "build $build does not exist for $project $version"
  fetch_json "$version_url/builds/$build" "$tmp/build.json"
  channel=$(jq -er '.channel' "$tmp/build.json")
  channel_allowed "$channel" || die "channel $channel is not allowed for $track"
else
  while IFS= read -r candidate; do
    fetch_json "$version_url/builds/$candidate" "$tmp/candidate.json"
    candidate_channel=$(jq -er '.channel' "$tmp/candidate.json")
    if channel_allowed "$candidate_channel"; then
      build=$candidate
      channel=$candidate_channel
      mv "$tmp/candidate.json" "$tmp/build.json"
      break
    fi
  done < <(jq -r '.builds[]' "$tmp/version.json")
  [[ -n "$build" ]] || die "no allowed build channel is available for $project $version on $track"
fi

resolved_build=$(jq -er '.id' "$tmp/build.json")
[[ "$resolved_build" == "$build" ]] || die "build response mismatch: expected $build, got $resolved_build"

download=$(jq -ce '.downloads["server:default"]' "$tmp/build.json")
url=$(jq -er '.url' <<<"$download")
sha256=$(jq -er '.checksums.sha256' <<<"$download")
filename=$(jq -er '.name' <<<"$download")
[[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || die "invalid SHA-256 in Fill response"
[[ "$url" == https://* ]] || die "Fill download URL must use HTTPS"

if [[ -z "$jre" ]]; then
  jre=${policy_jre:-$minimum_java}
fi
[[ "$jre" =~ ^[0-9]+$ ]] || die "JRE must be an integer"
((jre >= minimum_java)) || die "JRE $jre is below the Fill minimum Java $minimum_java"
java_image=$(jq -er --arg jre "$jre" '.java_images[$jre]' "$TRACKS_FILE") \
  || die "no pinned Java image is configured for JRE $jre"
[[ "$java_image" == *@sha256:* ]] || die "Java image must be pinned by digest"

wrapper_revision=$(jq -er '.wrapper_revision' "$TRACKS_FILE")
canonical_tag="$version-b$build-j$jre-r$wrapper_revision"

moving_tags='[]'
if [[ "$track" == current && -n "$policy" ]]; then
  moving_tags=$(jq -cn --arg version "$version" '["current", "latest", $version]')
elif [[ "$track" == previous && -n "$policy" ]]; then
  moving_tags=$(jq -cn --arg version "$version" '["previous", $version]')
elif [[ "$track" == preview && -n "$policy" ]]; then
  moving_tags=$(jq -cn --arg version "$version" '["preview", $version]')
fi

jq -cn \
  --arg project "$project" \
  --arg track "$track" \
  --arg version "$version" \
  --argjson build "$build" \
  --arg support "$support" \
  --arg channel "$channel" \
  --argjson java "$jre" \
  --argjson minimum_java "$minimum_java" \
  --arg java_image "$java_image" \
  --arg url "$url" \
  --arg sha256 "$sha256" \
  --arg filename "$filename" \
  --argjson wrapper_revision "$wrapper_revision" \
  --arg canonical_tag "$canonical_tag" \
  --arg compatibility_tag "$version-$build" \
  --argjson moving_tags "$moving_tags" \
  --argjson jvm_flags "$(jq -c '.version.java.flags.recommended // []' "$tmp/version.json")" \
  '{project:$project,track:$track,version:$version,build:$build,support:$support,channel:$channel,java:$java,minimum_java:$minimum_java,java_image:$java_image,url:$url,sha256:$sha256,filename:$filename,wrapper_revision:$wrapper_revision,canonical_tag:$canonical_tag,compatibility_tags:[$compatibility_tag],moving_tags:$moving_tags,jvm_flags:$jvm_flags}'
