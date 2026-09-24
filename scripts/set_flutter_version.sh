#!/usr/bin/env bash
#
# Pins versions.json to a single Flutter version.
#
#   scripts/set_flutter_version.sh 3.44.8   # an exact release
#   scripts/set_flutter_version.sh stable   # the current stable release
#   scripts/set_flutter_version.sh beta     # the current beta pre-release
#
# The version is validated against Flutter's official release index, so a typo
# fails here instead of failing later inside `git clone --branch`.
#
# Requires curl and jq. Invoked by the "Bump Flutter version" workflow, but
# safe to run locally.

set -euo pipefail

VERSIONS_FILE="${VERSIONS_FILE:-versions.json}"
RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

requested="${1:-}"
if [ -z "$requested" ]; then
    echo "Usage: $0 <flutter-version|stable|beta>" >&2
    exit 2
fi

releases_json=$(curl -fsSL "$RELEASES_URL")

resolve_channel() {
    local channel=$1 hash version
    hash=$(jq -r --arg c "$channel" '.current_release[$c] // empty' <<<"$releases_json")
    if [ -z "$hash" ]; then
        echo "Error: channel '$channel' not present in the release index" >&2
        return 1
    fi
    version=$(jq -r --arg h "$hash" '.releases[] | select(.hash == $h) | .version' <<<"$releases_json")
    if [ -z "$version" ]; then
        echo "Error: no release entry for channel '$channel' (hash $hash)" >&2
        return 1
    fi
    printf '%s' "$version"
}

case "$requested" in
    stable | beta | dev | master)
        flutter_version=$(resolve_channel "$requested")
        ;;
    *)
        flutter_version=$requested
        known=$(jq -r --arg v "$flutter_version" \
            '[.releases[] | select(.version == $v)] | length' <<<"$releases_json")
        if [ "$known" -eq 0 ]; then
            echo "Error: '$flutter_version' is not a published Flutter release." >&2
            echo "Recent stable releases:" >&2
            jq -r '[.releases[] | select(.channel == "stable")][:10] | .[] | "  " + .version' \
                <<<"$releases_json" >&2
            exit 1
        fi
        ;;
esac

# Minor-series alias: 3.44.8 also gets pushed as :3.44, so a project can track
# patch releases of one minor without editing its workflow.
minor_tag=$(cut -d. -f1,2 <<<"$flutter_version")

echo "Pinning to Flutter $flutter_version (tags: latest, $minor_tag)"

tmp=$(mktemp)
jq -n \
    --arg version "$flutter_version" \
    --arg minor "$minor_tag" \
    '{ images: [ { flutter_version: $version, tags: ["latest", $minor] } ] }' >"$tmp"

mv "$tmp" "$VERSIONS_FILE"
