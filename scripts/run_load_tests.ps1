[CmdletBinding()]
param(
    [ValidateSet('Smoke', 'Baseline', 'Scale')]
    [string]$Profile = 'Smoke',
    [string]$Environment = 'staging',
    [string]$AccountFile = 'load-tests\accounts.json',
    [switch]$AllowProduction
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
    throw 'k6 is not installed or not on PATH. Install k6, open a new PowerShell window, and rerun.'
}
if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
    throw 'Set SUPABASE_URL and SUPABASE_ANON_KEY for the staging project first.'
}

$resolvedAccountFile = Resolve-Path -LiteralPath $AccountFile -ErrorAction Stop
$accounts = @(Get-Content -LiteralPath $resolvedAccountFile -Raw | ConvertFrom-Json)
if ($accounts.Count -eq 0) { throw 'The synthetic account fixture is empty.' }

$profiles = @{
    Smoke = @{ Duration = '30s'; DiscoveryVus = 2; ChatVus = 1; LiveLocationVus = 1 }
    Baseline = @{ Duration = '3m'; DiscoveryVus = 20; ChatVus = 10; LiveLocationVus = 10 }
    Scale = @{ Duration = '5m'; DiscoveryVus = 100; ChatVus = 50; LiveLocationVus = 50 }
}
$selected = $profiles[$Profile]
$isProduction = $env:SUPABASE_URL -match 'tbdmucmrsftbrgvszvxa' -or $Environment -eq 'production'
if ($isProduction -and -not $AllowProduction) {
    throw 'Production load testing is blocked. Use staging, or pass -AllowProduction only in an approved maintenance window.'
}
if ($accounts.Count -lt $selected.LiveLocationVus) {
    throw "$Profile requires at least $($selected.LiveLocationVus) dedicated synthetic accounts so live-location writes do not collide on one rider row."
}
foreach ($account in $accounts) {
    foreach ($field in @('email', 'password', 'conversationId', 'liveRideSessionId')) {
        if (-not $account.$field) { throw "Every synthetic account needs $field for the combined suite." }
    }
}

New-Item -ItemType Directory -Force -Path 'load-tests\results' | Out-Null
$env:LOAD_TEST_ENVIRONMENT = $Environment
$env:LOAD_TEST_ACCOUNTS_FILE = ($resolvedAccountFile.Path -replace '\\', '/')
$env:LOAD_TEST_DURATION = $selected.Duration
$env:DISCOVERY_VUS = [string]$selected.DiscoveryVus
$env:CHAT_VUS = [string]$selected.ChatVus
$env:LIVE_LOCATION_VUS = [string]$selected.LiveLocationVus
$env:ALLOW_PRODUCTION_LOAD_TEST = if ($AllowProduction) { 'true' } else { 'false' }

Write-Host "Running RydMatch $Profile load test against $Environment..." -ForegroundColor Cyan
Write-Host "Discovery: $($selected.DiscoveryVus) VUs; chat: $($selected.ChatVus) VUs; live location: $($selected.LiveLocationVus) VUs; duration: $($selected.Duration)"
& k6 run '.\load-tests\rydmatch-scale.js'
if ($LASTEXITCODE -ne 0) {
    throw "k6 failed or a performance threshold was breached (exit code $LASTEXITCODE)."
}
