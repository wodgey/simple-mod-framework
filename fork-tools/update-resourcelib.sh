#!/usr/bin/env bash
# Pulls prebuilt ResourceLib DLLs from OrfeasZ/ZHMTools releases into "For Build/Third-Party".
# Needed after a game update when upstream SMF has not yet shipped its own ResourceLib update.
# Usage: bash fork-tools/update-resourcelib.sh [tag, e.g. v4.3.0]   (default: latest release)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/For Build/Third-Party"
TAG="${1:-}"
if [ -z "$TAG" ]; then
	TAG="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/OrfeasZ/ZHMTools/releases/latest | sed 's#.*/##')"
fi
echo "ZHMTools release: $TAG"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/rl.zip" "https://github.com/OrfeasZ/ZHMTools/releases/download/$TAG/ResourceLib-win-x64.zip"
unzip -q -o "$TMP/rl.zip" -d "$TMP/rl"

for f in ResourceLib_HM2.dll ResourceLib_HM2016.dll ResourceLib_HM3.dll ResourceLib_KNT.dll; do
	[ -f "$TMP/rl/$f" ] || { echo "Missing in release zip: $f" >&2; exit 1; }
	cp -f "$TMP/rl/$f" "$DEST/$f"
	echo "updated $f"
done

echo "$TAG" > "$ROOT/fork-tools/RESOURCELIB_VERSION"
echo "Recorded $TAG in fork-tools/RESOURCELIB_VERSION"
