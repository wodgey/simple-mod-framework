# Updating this fork after a HITMAN 3 game update

Last done: game 3.290.0, upstream SMF 2.33.42.

## Why this is needed

- SMF identifies the game by the **MD5** (not SHA256) of `Retail\HITMAN3.exe`, using the `gameHashes` table in `src/main.ts`. An unknown MD5 leaves the platform undefined.
- Upstream's own "update for game version X" commits also refresh `cleanPackageDefinition.txt`, the ResourceLib/ResourceTool DLLs and `hash_list.hmla`. Until upstream ships one, this fork can lag behind the game.
- `packagedefinition.txt` and `thumbs.dat` are encrypted in the game. SMF copies them raw and decrypts them itself, so they look like binary files. That is normal.

## One-time tooling (Windows)

- Node 18, Yarn 1, 7-Zip on PATH, Visual Studio Build Tools (MSVC)
- Rust 1.80 or newer: `rustup update stable` (older rustc fails on current `rayon-core`)
- `npm install -g typescript@5.6 pkg`
  - older TypeScript has no `--noCheck`; newer is ESM-only and crashes on Node 18
- Do not install `@napi-rs/cli` globally; the Rust build uses the copy in `rust/node_modules`

## Steps

1. **Steam:** verify integrity of game files, so `packagedefinition.txt` is vanilla.
2. **Sync upstream** (WSL):
   ```
   cd /mnt/c/dev/simple-mod-framework
   git fetch upstream --tags
   git merge upstream/main
   ```
   If `src/main.ts` conflicts, take upstream's version and re-add the hash in step 3:
   ```
   git checkout --theirs src/main.ts && git add src/main.ts && git commit --no-edit
   ```
3. **Add the MD5** (WSL, safe to re-run; it says so if upstream already added the hash):
   ```
   bash fork-tools/update-game-hash.sh
   ```
4. **Build** (PowerShell, normal window):
   ```
   & { powershell -ExecutionPolicy Bypass -File C:\dev\simple-mod-framework\fork-tools\build.ps1 }
   ```
   Output: `dist\` and `Release.zip`. The build deliberately drops the shipped `cleanPackageDefinition.txt` and extracts `latest-hashes.7z` last, so the fresh `hash_list.txt` is used.
5. **Install over the existing SMF folder** (keeps your caches):
   - Back up first: `Deploy.exe`, `Mod Manager.cmd`, `Mod Manager`, `Third-Party`, `Info`, `API`, `cleanPackageDefinition.txt` **and `config.json`**.
   - Copy from `dist` into the SMF folder, overwriting: `Deploy.exe`, `Mod Manager.cmd`, `Mod Manager`, `Third-Party`, `Info`, `API`.
   - Do **not** copy: `config.json`, `Mods`, `cleanThumbs.dat`, `cleanMicrosoftThumbs.dat`.
   - Delete the old `cleanPackageDefinition.txt` in the SMF folder. It regenerates on the next deploy.
   - If `config.json` is ever overwritten by mistake, **do not deploy yet.** `%LOCALAPPDATA%\Simple Mod Framework\lastDeploy.json` holds the last deployed config (load order, mod options, known mods). Rebuild `config.json` from it, minus the `platform` and `lastServerSideStates` fields.
6. **Publish** (WSL):
   ```
   git add -A && git commit -m "Update for game version X" && git push origin main
   GAME=X.Y.Z
   BASE=$(git describe --tags --abbrev=0 --match '[0-9]*.[0-9]*.[0-9]*')
   TAG="$BASE-hitman$GAME"
   git tag "$TAG" && git push origin "$TAG"
   gh release create "$TAG" Release.zip --repo wodgey/simple-mod-framework --title "SMF $BASE for HITMAN 3 $GAME" --notes "Unofficial build; see fork-tools/UPDATING.md"
   ```

## Known gaps

- `update-game-hash.sh` only handles the Steam base-game exe. Ansel-unlocked, Epic and Microsoft Store hashes are not added.
- `hash_list.hmla` comes from the repo and is stale until upstream updates it. SMF's own code does not read it; if ResourceTool complains about unknown hashes after a game update, this is the first suspect.
- If a deploy fails with resource-format errors after a big game update, the bundled ResourceLib/ResourceTool binaries may be stale. Wait for upstream's update commit and merge it.
- Do not enable Actions on the fork: upstream's `release.yml` hard-codes `atampy25/simple-mod-framework` as the release target and would fail on tag pushes.
