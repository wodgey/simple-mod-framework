# SMF fork handover: update zip and Mod Manager banner

Last updated 2026-11-07. Written so another Claude session or a contributor can pick up the work without the original conversation.

Two pieces of work are not started: publish a small update zip from CI, and replace the Mod Manager's update banner with an honest one. The rest of the fork's pipeline is built and tested.

## Where things stand

The fork (`wodgey/simple-mod-framework`) builds only from its own source and never touches Atampy25's repo at build time. His changes arrive only when merged on purpose. The source is frozen at his 2.33.42; the Epic, Ansel and Microsoft hashes, `cleanThumbs.dat` and `hash_list.hmla` are as of that merge.

- **Daily check:** `.github/workflows/check-hash.yml` runs at 04:00 UTC. It uses DepotDownloader with a throwaway Steam account (secrets `STEAM_USER`, `STEAM_PASSWORD`; demo app `1847520`, depot `1659041`, a full copy of the retail game) to fetch `Retail/HITMAN3.exe` and `Runtime/packagedefinition.txt`. It commits `hitman-hash.txt` (the exe's MD5) and `hitman-packagedefinition.txt` when either changes.
- **Build:** `.github/workflows/fork-build.yml` runs on pushes to main, after every check-hash run (`workflow_run`) and by hand. It runs on `windows-latest` with `fork-tools/build.ps1` (Node 18, Rust 1.80 or newer, TypeScript 5.6, `pkg`).
- **Build inputs added in CI:** the Steam MD5 is inserted into the `gameHashes` table in `src/main.ts` by `fork-tools/update-game-hash.sh`. The ResourceLib DLLs and `ResourceTool.exe` are always taken from the latest OrfeasZ/ZHMTools release. The depot package definition becomes `cleanPackageDefinition.txt` (the build sets `SMF_KEEP_CLEAN_PACKAGEDEF=1`). The hash list comes from the latest glacier-modding/hitman-hashes download, extracted last.
- **Release:** tag `auto-<base>-<source key>-zhm<tag>-hh<tag>-m<key>`, one asset `SMF-<tag>.zip` (the full zip). A release with the same tag is skipped. The newest 5 `auto-*` releases are kept.
- **Tested:** a full release deployed cleanly on wodgey's install, and on 2026-11-04 so did the update-only file set in Task 1.

Local paths used by wodgey: the repo is `/mnt/c/dev/simple-mod-framework` (WSL); the live install is `C:\Program Files (x86)\Steam\steamapps\common\HITMAN 3\Simple Mod Framework`. The update guide is `fork-tools/UPDATING.md`.

## Task 1: update zip in CI

Every build should also publish `SMF-update-<tag>.zip`, a small zip for people who already have SMF installed. The file list below was tested by hand on 2026-11-04: applied over wodgey's install, then a normal deploy ran with only the usual Freelancer Variations soundbank warnings, and the game launched with mods loaded. `config.json`, `Mods` and `cleanThumbs.dat` were untouched.

| Path in the zip | In? | Reason |
| --- | --- | --- |
| `Deploy.exe` | Yes | The framework itself, with the hash table baked in |
| `Third-Party/ResourceLib_HM2.dll`, `_HM2016`, `_HM3`, `_KNT` | Yes | Resource type layouts; change with game updates |
| `Third-Party/ResourceTool.exe` | Yes | Comes from the same ZHMTools release |
| `Third-Party/hash_list.txt`, `hash_list.hmla` | Yes | Hash names; `hash_list.txt` is 258 MB uncompressed |
| `cleanPackageDefinition.txt` | Yes | The depot copy, only when `hitman-packagedefinition.txt` exists |
| `Mod Manager/` | No | Large Electron app; an update zip without it is untested |
| `config.json`, `Mods/` | No | The user's settings and mods (`Mods` also ships `Realistic AI`) |
| `cleanThumbs.dat` | No | The shipped copy is stale and not yet confirmed good |
| `rpkg-cli.exe`, `assimp.dll`, `quickentity_ffi.dll`, `Info/`, `API/` | No | Do not change with game updates |

Size: the staged set is 318 MB uncompressed. A one-off zip made from it was about 61 MB.

Steps:

1. In `fork-build.yml`, after the Build step, zip the files above from the build's `dist` folder (`build.ps1` leaves `dist` and `Release.zip` in the repo root, so in CI it is under `fork/`; check the path) with `7z`, keeping paths relative to `dist`.
2. Name it `SMF-update-<tag>.zip` and attach it to the same release as `SMF-<tag>.zip` in the existing `gh release create` call.
3. Add to the release notes how to apply it: close Mod Manager and the game, back up, extract over the SMF folder with overwrite, run a normal deploy.
4. Leave the retention rule (newest 5 `auto-*` releases) as it is.

Decisions still open:

- **`hash_list.hmla`:** the release copy is the old 1,205,394 bytes, while Atampy25's 3.290.1 copy is 1,207,838. The hitman-hashes archive does not supply it, and what reads it is unknown. It was in the tested set and worked; recommended: keep it in.
- **`cleanThumbs.dat`:** leave it out until a depot probe of `Retail/thumbs.dat` shows it can be used.
- **Mod Manager's built-in updater:** it downloads Atampy25's `Release.zip` and has nothing to do with this zip. Do not point it at the update zip.

## Task 2: Mod Manager update banner

The Mod Manager tells users their install "needs updating" whenever Atampy25 publishes a release, even when the fork already covers it. wodgey wants the banner to give accurate information and let the user decide. All of this is in `Mod Manager/src/routes/+page.svelte`.

What it does today (read from the source; line numbers are approximate):

- `checkForUpdates()` (about line 137) fetches `api.github.com/repos/atampy25/simple-mod-framework/releases/latest` and `/releases`, and shows the banner when `semver.lt(FrameworkVersion, release.tag_name)`. The title ("Patch / Feature / Major update available", about line 461) comes from `semver.diff`.
- The Update button runs `startFrameworkUpdate()` (about line 192). It downloads Atampy25's `Release.zip`, extracts it to `./staging`, deletes `Mods`, `cleanPackageDefinition.txt`, `cleanThumbs.dat`, `config.json` and the Electron runtime files from staging, and copies the rest over the install. The user's data survives, but `Deploy.exe` and `Third-Party` become Atampy25's, so the install stops being the fork's build.
- `FrameworkVersion` is set in three places: `src/core.ts`, `Mod Manager/src/lib/utils.ts` and `For Build/Mods/Realistic AI/manifest.json` (`frameworkVersion`). It is frozen at 2.33.42, so the banner appears for every Atampy25 release after it (2.33.45 at the time of writing).

Decisions made:

- **Keep the real version and the real check.** A fake high version such as 2.33.999 was rejected. The banner is the only signal users get if the fork's pipeline stalls, and wodgey rarely reads GitHub emails.
- **No second update source.** Installs still come only from where the user chooses. Reading the fork's releases for display only is acceptable.
- **Deferential wording**, and two checkboxes: one that enables the Update button, and one that hides the banner until SMF is next updated (keyed to the installed build, so a new fork release brings it back).
- **Release dates and version numbers are not evidence.** A stale Atampy25 release can be stamped later than a fork release, and the fork's number never moves. Compare what each build supports.

### Phase A (small, do first)

Reword the banner, add the two checkboxes and gate the Update button on the first. For the "hide" key, have the build write a `BUILD_INFO.json` into the zip with the release tag, build time and the exe hashes it accepts. Draft text:

> **Atampy25's official release 2.33.45 is available.** This fork exists to keep mods working in the gap between a game update and Atampy25's release. The best long-term choice is to switch to his official release. Staying on this build is fine too, unless the changes listed below matter to you. Your mods and settings are kept either way.

- [ ] Switch to Atampy25's official release (enables the Update button)
- [ ] Hide this until SMF is updated

### Phase B (later)

Replace the generic text with one verdict line, with the details behind a "show details" link. Inputs:

1. **Exe hashes:** read `src/main.ts` at Atampy25's latest release tag (raw GitHub file), take the uncommented `// base game` lines per platform, and compare them with the hashes in `BUILD_INFO.json`. Skip the Ansel lines. His Epic base hash is not in the fork, so Epic users would correctly see that he supports a version the fork does not.
2. **Key files:** compare git blob SHAs from the GitHub tree API for his tag with those recorded in `BUILD_INFO.json`: the four ResourceLib DLLs, `ResourceTool.exe`, `cleanPackageDefinition.txt`, `cleanThumbs.dat`, `hash_list.hmla`, `rpkg-cli.exe`. `hash_list.txt` cannot be compared (it is downloaded at build time and not recorded), so show "can't verify" for it.
3. **Release notes:** lines like "fix(deploy): update for game version…" are game-update-only. Anything else counts as a difference and is listed.

Verdicts: same game version and key files; fork built from newer sources; Atampy25's built from newer sources; can't tell (a fetch or parse failed, so say so and do not guess). For the first, the intended meaning is: the update isn't needed because it contains the same as this build, and installing it won't harm mods or settings, but it replaces the fork's program files and the install then follows Atampy25's releases.

Expected on day one: `ResourceTool.exe` (the fork uses a newer ZHMTools build), `cleanThumbs.dat` and `hash_list.hmla` (stale in the fork) will show as different. That is correct, and is a reason to fix those files first.

Both phases need a Mod Manager rebuild, so they ship as a full release, not an update zip. CI cannot test the GUI; test by running the built Mod Manager from a local build.

## Working with wodgey, and traps already hit

How wodgey wants you to work:

- Succinct replies, no flattery, no recaps.
- Dev commands in WSL/bash. PowerShell only when needed, wrapped in `& { }`.
- The last sentence before every code block is a banner saying where to paste it: `********* W S L *********` or `******* POWERSHELL ********`.
- Multi-line bash goes inside a `{ }` wrapper so the command and its output stay separate.
- Downloadable files carry an incremented version number (`_v1`, `_v2`).
- Commands are pasted only when wodgey says they are ready. Keep each step small and name the next one in a line.

Decisions to respect:

- **Air-gapped from Atampy25.** Never fetch his source at build time. His changes are merged only deliberately (`git fetch upstream --tags`, `git merge upstream/main`).
- **Everything runs in GitHub.** No automation that depends on one machine being on or on a Windows login. The check is daily; no 6-hourly runs. A changed MD5 must trigger a build.
- **The public build does not bypass the exe hash check.** Only the Steam hash is scraped from the depot. Epic scraping was rejected (token upkeep). Epic and Ansel hashes are copied by hand from Atampy25's table when needed. A flow where an Epic player opens an issue and wodgey labels it was discussed but never built.
- **No game files are shipped,** except `cleanPackageDefinition.txt` (the same file Atampy25 ships).
- **Do not click Update in the Mod Manager on the fork.** It swaps in Atampy25's build.

Traps already hit:

- Commits pushed with the default `GITHUB_TOKEN` do not start `push` workflows, which is why the build listens for `workflow_run`.
- That token also cannot push changes under `.github/workflows`. wodgey pushes those from their machine after `gh auth refresh -s workflow`.
- With two remotes, `gh` needs `gh repo set-default`.
- Local builds rewrite `Mod Manager/package*.json` and `rust/yarn.lock`. Discard them with `git checkout --` or use `git pull --rebase --autostash`.
- Yarn needs `corepack enable` (`rust/package.json` pins yarn 3.6.0). TypeScript must be 5.6 (`--noCheck` fails on 5.5). Rust must be 1.80 or newer.
- `pkg` prints many "Cannot resolve" and dynamic-require warnings. They are harmless as long as a roughly 45 MB `Deploy.exe` is produced.
- Never copy `config.json` from a release over an install. If it is overwritten, `%LOCALAPPDATA%\Simple Mod Framework\lastDeploy.json` holds the settings.
- SMF identifies the game by the MD5 of `Retail\HITMAN3.exe`. It does not check the file's date, and it is not SHA256.
- Cron times are UTC, and scheduled workflows pause after 60 days without a commit.
- Check claims against the source. Several early statements here (what GSE changes, what the Mod Manager updater wipes) were wrong until the code was read.
- The Claude sandbox can clone public repos but has no authenticated GitHub access, so wodgey runs commands and pastes results.

## Not done, and how to know each task is finished

Known gaps, none urgent:

- **`cleanThumbs.dat` is stale.** Atampy25 changed it for 3.290.1 (still 1,532 bytes, different contents) and the fork ships the old one. SMF uses a shipped copy as is and does not repair it. A candidate fix is to add `Retail/thumbs.dat` to the depot download in `check-hash.yml`, as was done for the package definition, after a probe shows the depot copy is the vanilla file.
- **`hash_list.hmla` is stale.** Its source and consumer are unknown (see Task 1).
- **Frozen at the last merge:** `FrameworkVersion` 2.33.42 and the Epic, Ansel and Microsoft hashes. Automating Epic was declined.
- **rpkg-cli** is the same build Atampy25 ships. A newer upstream version exists; wodgey chose not to swap it ("if it ain't broke"). If that is ever done, test in a backed-up install first.
- **An unexplained release tag.** A release named like `auto-2.33.45-c6d7ae2-zhmupstream-hhv381-…` appeared on 2026-11-04. The current workflow writes `auto-2.33.42-<source key>-zhm<tag>-…`, so it does not match. It was not investigated; the first line of that release's notes says how it was built.

Task 1 is finished when:

- a build publishes both `SMF-<tag>.zip` and `SMF-update-<tag>.zip`;
- `7z l` of the update zip shows only the paths in the table;
- applied over a backed-up install, a normal deploy shows no ResourceLib or "Unknown game version" errors;
- checksums of `config.json`, `Mods` and `cleanThumbs.dat` are the same before and after.

Task 2, Phase A, is finished when:

- the new text appears only when Atampy25's version is newer than the installed one;
- the Update button stays disabled until the first box is ticked;
- "Hide" survives a restart and comes back after a new fork release;
- `FrameworkVersion` is unchanged, so the check is still real;
- a full release has been built and its Mod Manager has been run locally.
