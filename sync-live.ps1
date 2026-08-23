# Copy this repo into the Ascension live AddOns folder.
# Used by Cursor hooks after edits, and safe to run by hand.

$ErrorActionPreference = "Continue"

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = $env:DISPELLER_COA_LIVE
if (-not $dest) {
    $dest = "C:\Ascension\Launcher\resources\ascension-live\Interface\AddOns\Dispeller_CoA"
}

$stamp = Join-Path $env:TEMP "dispeller-coa-sync.stamp"
if (Test-Path $stamp) {
    $age = (Get-Date) - (Get-Item $stamp).LastWriteTime
    if ($age.TotalSeconds -lt 1.5) {
        exit 0
    }
}

if (-not (Test-Path $src)) {
    Write-Error "Source missing: $src"
    exit 1
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null

& robocopy $src $dest /E /XO /FFT /R:1 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np `
    /XD .git .cursor `
    /XF .gitignore sync-live.ps1
$code = $LASTEXITCODE
# robocopy: 0-7 are success classes
if ($code -ge 8) {
    exit $code
}

Set-Content -Path $stamp -Value (Get-Date).ToString("o") -ErrorAction SilentlyContinue
exit 0
