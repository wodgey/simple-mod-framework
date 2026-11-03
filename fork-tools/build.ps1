# Builds Deploy.exe, the Mod Manager GUI, dist\ and Release.zip.
# Run: powershell -ExecutionPolicy Bypass -File fork-tools\build.ps1   (see UPDATING.md for prerequisites)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Need($cmd) {
	if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Missing tool on PATH: $cmd" }
}
function Run($label, [scriptblock]$sb) {
	Write-Host "== $label"
	$global:LASTEXITCODE = 0
	& $sb
	if ($LASTEXITCODE -ne 0) { throw "$label failed (exit code $LASTEXITCODE)" }
}
function Rc {
	# robocopy: exit codes below 8 mean success
	robocopy @args | Out-Null
	if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE): $args" }
	$global:LASTEXITCODE = 0
}

"node", "npm", "yarn", "rustc", "cargo", "tsc", "pkg", "7z" | ForEach-Object { Need $_ }

$nodeMajor = [int]((node -v).TrimStart('v').Split('.')[0])
if ($nodeMajor -ne 18) { Write-Warning "Node $nodeMajor detected; this build is only known to work on Node 18." }
$rv = [version]((rustc -V) -split ' ')[1]
if ($rv -lt [version]'1.80.0') { throw "rustc $rv is too old - run: rustup update stable" }
$tv = [version](((tsc -v) -replace 'Version ', '').Trim())
if ($tv -lt [version]'5.6.0' -or $tv.Major -ne 5) { throw "tsc $tv unsupported - run: npm install -g typescript@5.6" }

Run "npm install (root)" { npm install }
Run "yarn install (rust)" { yarn --cwd rust install }
Run "yarn build (rust)" { yarn --cwd rust build }
Copy-Item .\rust\index.d.ts .\src\smf-rust.d.ts -Force
Copy-Item .\rust\rust.win32-x64-msvc.node .\src\smf-rust.node -Force

$env:NODE_OPTIONS = "--max-old-space-size=4096"
New-Item -ItemType Directory -Force -Path .\node_modules\piscina | Out-Null
Rc .\piscina .\node_modules\piscina /E /is /it
Run "tsc" { tsc --noCheck }
Copy-Item .\src\smf-rust.node .\compiled\smf-rust.node -Force
Run "pkg (Deploy.exe)" { pkg package.json --targets node18-win-x64 --output Deploy.exe --compress Brotli }

Run "npm install (Mod Manager)" { npm --prefix "Mod Manager" install }
Run "npm build (Mod Manager)" { npm --prefix "Mod Manager" run build }

Write-Host "== assembling dist"
Remove-Item dist -Recurse -Force -ErrorAction SilentlyContinue
"Third-Party", "Info", "API", "Mod Manager" | ForEach-Object { New-Item -ItemType Directory "dist\$_" | Out-Null }
Rc .\Third-Party .\dist\Third-Party /E
Rc ".\For Build" .\dist /E
Rc .\docs .\dist\Info /E
Rc .\compiled .\dist\API /E *.d.ts
Rc ".\Mod Manager\dist\win-unpacked" ".\dist\Mod Manager" /E
Copy-Item Deploy.exe dist -Force
Set-Content -Path "dist\Mod Manager.cmd" -Value "@echo off`ncd `"Mod Manager`"`nstart `"`" `"Mod Manager.exe`"" -Encoding ASCII

# The shipped copy matches whatever game version upstream last built for. Drop it so SMF regenerates it
# from the installed game's Runtime\packagedefinition.txt (verify game files in Steam first).
if (-not $env:SMF_KEEP_CLEAN_PACKAGEDEF) { Remove-Item "dist\cleanPackageDefinition.txt" -Force -ErrorAction SilentlyContinue }

# Extract last so the fresh hash list wins over anything shipped in the repo.
Run "download latest hashes" { Invoke-WebRequest "https://github.com/glacier-modding/hitman-hashes/releases/latest/download/latest-hashes.7z" -OutFile latest-hashes.7z }
Run "extract latest hashes" { 7z x latest-hashes.7z -o".\dist\Third-Party" -y }
Remove-Item latest-hashes.7z -Force

Run "zip" {
	Remove-Item Release.zip -Force -ErrorAction SilentlyContinue
	7z a -tzip "$root\Release.zip" "$root\dist\*"
}

Write-Host ""
Write-Host "Done: $root\dist and $root\Release.zip"
