# Install the mods of this repo as Claude Code plugins through its marketplace.
# Usage: claude\scripts\install-mods.ps1 [-Scope user|project|local] [-Uninstall] [-List] [mod-name ...]
# -Scope project installs into the folder you run this from, not into this repo.
param(
  [ValidateSet('user', 'project', 'local')][string]$Scope = 'user',
  [switch]$Uninstall,
  [switch]$List,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Names = @()
)
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 turns a native command's stderr into an error record. Under 'Stop' that
# throws, so every call to claude runs here with 'Continue' and the caller reads $LASTEXITCODE.
function Invoke-Claude {
  $ErrorActionPreference = 'Continue'
  & claude @args
}

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$market = 'claude-mods'
$manifest = Join-Path $repo '.claude-plugin/marketplace.json'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  # Write-Error would throw here, because of 'Stop' above, and the exit would never run.
  [Console]::Error.WriteLine('The claude command is not on PATH. Install Claude Code first.')
  exit 1
}

# A mod is a folder in claude/mods/ that the marketplace manifest lists.
if ($Names.Count -eq 0) {
  $text = Get-Content -Raw $manifest
  $Names = Get-ChildItem (Join-Path $repo 'claude/mods') -Directory |
    Where-Object { $text.Contains("`"./claude/mods/$($_.Name)`"") } |
    ForEach-Object Name
}

$installed = (Invoke-Claude plugin list 2>$null) -join "`n"
function Test-Installed($name) { $installed.Contains("$name@$market") }

if ($List) {
  foreach ($n in $Names) { if (Test-Installed $n) { "installed  $n" } else { "missing    $n" } }
  exit 0
}

if ($Uninstall) {
  foreach ($n in $Names) {
    if (Test-Installed $n) { Invoke-Claude plugin uninstall "$n@$market" --scope $Scope; "removed    $n" }
    else { "skipped    $n (not installed)" }
  }
  exit 0
}

# Point the marketplace at this clone. Re-adding repoints a GitHub-sourced
# marketplace of the same name. Never remove it: that deletes plugin data.
Invoke-Claude plugin marketplace add $repo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$status = 0
foreach ($n in $Names) {
  if (Test-Installed $n) {
    Invoke-Claude plugin update "$n@$market" --scope $Scope
  } else {
    Invoke-Claude plugin install "$n@$market" --scope $Scope
  }
  if ($LASTEXITCODE -ne 0) { $status = 1 }
}

'Restart Claude Code to load the mods.'
exit $status
