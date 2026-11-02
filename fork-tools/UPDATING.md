# Updating this fork after a HITMAN 3 game update

Last done: game 3.290.0, upstream SMF 2.33.42, ZHMTools (ResourceLib) v4.3.0. Deploy-tested with a real mod set.

## What a game update breaks

1. **Platform detection.** SMF identifies the game by the **MD5** (not SHA256) of `Retail\HITMAN3.exe`, using the `gameHashes` table in `src/main.ts`. An unknown MD5 leaves the platform undefined.
2. **ResourceLib type tables.** After an update, any mod that patches an entity fails during `quickentity-rs.exe entity convert` with `Could not find type '...'. ResourceLib might need to be updated.` followed by a `Failed to read file as RT struct` panic. The fix is newer ResourceLib DLLs. They come from [OrfeasZ/ZHMTools](https://github.com/OrfeasZ/ZHMTools/releases), usually within days of the game update.
3. **Vanilla copies.** `cleanPackageDefinition.txt` must be a copy of the new game's `packagedefinition.txt`. The build drops the shipped one so SMF regenerates it.

Upstream's "update for game version X" commit refreshes all of these. Once it exists, merging it replaces steps 3 and 4. `rpkg-cli` is not affected by game updates. `packagedefinition.txt` and `thumbs.dat` are encrypted in the game; SMF copies them raw, so they look like binary files. That is normal.

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
   If `src/main.ts` conflicts, take upstream's version, then do step 3:
   ```
   git checkout --theirs src/main.ts && git add src/main.ts && git commit --no-edit
   ```
   If binaries under `For Build/Third-Party` conflict, upstream has shipped its own update: take theirs (`git checkout --theirs -- <file>`) and skip step 4.
3. **Add the MD5** (WSL, safe to re-run; says so if upstream already added it):
   ```
   bash fork-tools/update-game-hash.sh
   ```
4. **Update ResourceLib**, only if upstream SMF has not done so yet. Find the newest [ZHMTools release](https://github.com/OrfeasZ/ZHMTools/releases) published after the game update, then:
   ```
   bash fork-tools/update-resourcelib.sh vX.Y.Z
   ```
   To test before committing anything, copy the four `ResourceLib_*.dll` files into the live SMF `Third-Party` folder and deploy.
5. **Build** (PowerShell, normal window):
   ```
   & { powershell -ExecutionPolicy Bypass -File C:\dev\simple-mod-framework\fork-tools\build.ps1 }
   ```
   Output: `dist\` and `Release.zip`. The build drops the shipped `cleanPackageDefinition.txt` and extracts `latest-hashes.7z` last, so the fresh `hash_list.txt` wins.
6. **Install over the existing SMF folder** (keeps your caches):
   - Back up first: `Deploy.exe`, `Mod Manager.cmd`, `Mod Manager`, `Third-Party`, `Info`, `API`, `cleanPackageDefinition.txt` **and `config.json`**.
   - Copy from `dist` into the SMF folder, overwriting: `Deploy.exe`, `Mod Manager.cmd`, `Mod Manager`, `Third-Party`, `Info`, `API`.
   - Do **not** copy: `config.json`, `Mods`, `cleanThumbs.dat`, `cleanMicrosoftThumbs.dat`.
   - Delete the old `cleanPackageDefinition.txt` in the SMF folder. It regenerates on the next deploy.
   - If `config.json` is ever overwritten by mistake, **do not deploy yet.** `%LOCALAPPDATA%\Simple Mod Framework\lastDeploy.json` holds the last deployed config (load order, mod options, known mods). Rebuild `config.json` from it, minus the `platform` and `lastServerSideStates` fields.
7. **Deploy-test** with your real mod set. The ResourceLib error in "What a game update breaks" means step 4 is needed or the DLLs are still too old.
8. **Publish** (WSL):
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
- `ResourceTool.exe` was left alone for 3.290.0 (same size as the copy SMF ships). If a game update needs it, copy it from the ZHMTools `ResourceTool-win-x64.zip` into `For Build/Third-Party`.
- `hash_list.hmla` comes from the repo and is stale until upstream updates it. SMF's own code does not read it; if ResourceTool complains about unknown hashes, this is the first suspect.
- Do not enable Actions on the fork: upstream's `release.yml` hard-codes `atampy25/simple-mod-framework` as the release target and would fail on tag pushes.

## Automation (GitHub Actions)

Two workflows do the routine work:

- `check-hash.yml` ("Check Hitman 3 MD5", daily): downloads `Retail/HITMAN3.exe` from the Steam depot with DepotDownloader, and commits its MD5 to `hitman-hash.txt` when it changed.
- `fork-build.yml`: builds upstream `main` plus this fork's overlay (the MD5 from `hitman-hash.txt`, newer ZHMTools ResourceLib DLLs if upstream has not updated them, a fresh hash list) and publishes an `auto-*` release when anything changed. It runs after every `check-hash` run (`workflow_run`; commits made with the default token do not trigger `push` workflows), every 6 hours, and on pushes to `fork-tools/` or `hitman-hash.txt`. The last 5 are kept. The fork's own `src/` is not used, so no merging is needed.

CI cannot deploy-test, so test an auto release before relying on it. Upstream's own workflows are disabled in the fork on purpose (their Release workflow targets atampy25's repo). If the scheduled runs stop after 60 days without commits, re-enable them in the Actions tab. If `check-hash` starts failing, check the `STEAM_USER` / `STEAM_PASSWORD` secrets and whether Steam is asking the account for a login confirmation.

## Automation (GitHub Actions)

Two workflows do the routine work:

- `check-hash.yml` ("Check Hitman 3 MD5", daily): downloads `Retail/HITMAN3.exe` from the Steam depot with DepotDownloader, and commits its MD5 to `hitman-hash.txt` when it changed.
- `fork-build.yml`: builds upstream `main` plus this fork's overlay (the MD5 from `hitman-hash.txt`, newer ZHMTools ResourceLib DLLs if upstream has not updated them, a fresh hash list) and publishes an `auto-*` release when anything changed. It runs after every `check-hash` run (`workflow_run`; commits made with the default token do not trigger `push` workflows), every 6 hours, and on pushes to `fork-tools/` or `hitman-hash.txt`. The last 5 are kept. The fork's own `src/` is not used, so no merging is needed.

CI cannot deploy-test, so test an auto release before relying on it. Upstream's own workflows are disabled in the fork on purpose (their Release workflow targets atampy25's repo). If the scheduled runs stop after 60 days without commits, re-enable them in the Actions tab. If `check-hash` starts failing, check the `STEAM_USER` / `STEAM_PASSWORD` secrets and whether Steam is asking the account for a login confirmation.

## Automation (GitHub Actions)

Two workflows do the routine work:

- `check-hash.yml` ("Check Hitman 3 MD5", daily): downloads `Retail/HITMAN3.exe` from the Steam depot with DepotDownloader, and commits its MD5 to `hitman-hash.txt` when it changed.
- `fork-build.yml`: builds upstream `main` plus this fork's overlay (the MD5 from `hitman-hash.txt`, newer ZHMTools ResourceLib DLLs if upstream has not updated them, a fresh hash list) and publishes an `auto-*` release when anything changed. It runs after every `check-hash` run (`workflow_run`; commits made with the default token do not trigger `push` workflows), every 6 hours, and on pushes to `fork-tools/` or `hitman-hash.txt`. The last 5 are kept. The fork's own `src/` is not used, so no merging is needed.

CI cannot deploy-test, so test an auto release before relying on it. Upstream's own workflows are disabled in the fork on purpose (their Release workflow targets atampy25's repo). If the scheduled runs stop after 60 days without commits, re-enable them in the Actions tab. If `check-hash` starts failing, check the `STEAM_USER` / `STEAM_PASSWORD` secrets and whether Steam is asking the account for a login confirmation.
