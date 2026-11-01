#!/usr/bin/env bash
# Adds the MD5 of the installed HITMAN3.exe to the gameHashes table in src/main.ts (Steam, base game).
# SMF identifies the game by MD5 (not SHA256). Safe to re-run: does nothing if the hash is already present.
# Usage: bash fork-tools/update-game-hash.sh [path-to-HITMAN3.exe]
set -euo pipefail

EXE="${1:-/mnt/c/Program Files (x86)/Steam/steamapps/common/HITMAN 3/Retail/HITMAN3.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="$ROOT/src/main.ts"

[ -f "$EXE" ]  || { echo "HITMAN3.exe not found: $EXE" >&2; exit 1; }
[ -f "$MAIN" ] || { echo "src/main.ts not found: $MAIN" >&2; exit 1; }

export H="$(md5sum "$EXE" | cut -d' ' -f1)"
echo "HITMAN3.exe MD5: $H"

if grep -q "\"$H\"" "$MAIN"; then
	echo "Already present in src/main.ts - nothing to do."
else
	perl -pi -e 'if(!$d && /Platform\.steam, \/\/ base game/){print "\t\"$ENV{H}\": Platform.steam, // base game (added by update-game-hash.sh)\n"; $d=1}' "$MAIN"
	grep -q "\"$H\"" "$MAIN" || { echo "Insert failed: no 'Platform.steam, // base game' anchor line found in src/main.ts." >&2; exit 1; }
	echo "Inserted into src/main.ts."
fi

echo
sed -n '/^const gameHashes/,/^}/p' "$MAIN"
