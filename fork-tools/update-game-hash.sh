#!/usr/bin/env bash
# Adds an MD5 to the gameHashes table in src/main.ts (Steam, base game). Safe to re-run.
# SMF identifies the game by MD5 (not SHA256) of Retail\HITMAN3.exe.
# Usage:  bash fork-tools/update-game-hash.sh [path-to-HITMAN3.exe]
# Env:    MD5=<hash>        use this hash instead of hashing the exe (CI)
#         SMF_ROOT=<dir>    patch another checkout instead of this repo (CI)
set -euo pipefail

ROOT="${SMF_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MAIN="$ROOT/src/main.ts"
[ -f "$MAIN" ] || { echo "src/main.ts not found: $MAIN" >&2; exit 1; }

if [ -n "${MD5:-}" ]; then
	H="$MD5"
else
	EXE="${1:-/mnt/c/Program Files (x86)/Steam/steamapps/common/HITMAN 3/Retail/HITMAN3.exe}"
	[ -f "$EXE" ] || { echo "HITMAN3.exe not found: $EXE" >&2; exit 1; }
	H="$(md5sum "$EXE" | cut -d' ' -f1)"
fi
[[ "$H" =~ ^[0-9a-f]{32}$ ]] || { echo "Not a valid MD5: $H" >&2; exit 1; }
export H
echo "MD5: $H"

if grep -q "\"$H\"" "$MAIN"; then
	echo "Already present in src/main.ts - nothing to do."
else
	perl -pi -e 'if(!$d && /Platform\.steam, \/\/ base game/){print "\t\"$ENV{H}\": Platform.steam, // base game (added by update-game-hash.sh)\n"; $d=1}' "$MAIN"
	grep -q "\"$H\"" "$MAIN" || { echo "Insert failed: no 'Platform.steam, // base game' anchor in src/main.ts." >&2; exit 1; }
	echo "Inserted into src/main.ts."
fi
