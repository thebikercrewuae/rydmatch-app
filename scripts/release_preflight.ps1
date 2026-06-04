[CmdletBinding()]
param(
    [switch]$RequireEnvironment,
    [switch]$CheckSupabase,
    [switch]$SkipAnalyze,
    [switch]$SkipTests,
    [string]$SupabaseProjectRef = "tbdmucmrsftbrgvszvxa"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Pass([string]$Message) {
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Add-Warning([string]$Message) {
    $warnings.Add($Message)
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Add-Error([string]$Message) {
    $errors.Add($Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Test-RequiredPath([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Add-Pass "Found $Path"
    } else {
        Add-Error "Missing required path: $Path"
    }
}

function Test-EnvironmentVariable([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        if ($RequireEnvironment) {
            Add-Error "$Name is empty or missing"
        } else {
            Add-Warning "$Name is not set locally; confirm it exists in Codemagic"
        }
    } else {
        Add-Pass "$Name is configured"
    }
}

Write-Host "Running RydMatch release preflight..." -ForegroundColor Cyan

@(
    "pubspec.yaml",
    "lib\main.dart",
    "android\app\build.gradle.kts",
    "android\app\src\main\AndroidManifest.xml",
    "codemagic.yaml",
    "assets",
    "supabase\functions",
    "supabase\migrations",
    "supabase\functions\strava-auth\index.ts",
    "supabase\functions\admin-growth-dashboard\index.ts",
    "supabase\functions\livekit-token\index.ts"
) | ForEach-Object { Test-RequiredPath $_ }

$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$' | Select-Object -First 1
$version = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value.Trim() } else { "" }
if ($version -match '^\d+\.\d+\.\d+\+[1-9]\d*$') {
    Add-Pass "App version is valid: $version"
} else {
    Add-Error "pubspec.yaml version must look like 1.0.16+16 and use a positive version code"
}

@(
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "GOOGLE_MAPS_API_KEY",
    "STRAVA_CLIENT_ID",
    "STRAVA_REDIRECT_URI",
    "REVENUECAT_ANDROID_API_KEY"
) | ForEach-Object { Test-EnvironmentVariable $_ }

$manifest = Get-Content -Raw -Path "android\app\src\main\AndroidManifest.xml"
if (
    $manifest.Contains('android:scheme="rydmatch"') -and
    $manifest.Contains('android:host="rydmatch.com"') -and
    $manifest.Contains('android:path="/strava-callback"')
) {
    Add-Pass "Android Strava callback intent filter is configured"
} else {
    Add-Error "Android Strava callback intent filter is incomplete"
}

$rocketReferences = Get-ChildItem -Path "lib" -Recurse -File |
    Select-String -Pattern "rocket\.new" -CaseSensitive:$false
if ($rocketReferences) {
    Add-Error "Found rocket.new in app source"
} else {
    Add-Pass "No rocket.new references found in app source"
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExe = if ($flutterCommand) { $flutterCommand.Source } else { $null }
if (-not $flutterExe -and (Test-Path -LiteralPath "C:\src\flutter\bin\flutter.bat")) {
    $flutterExe = "C:\src\flutter\bin\flutter.bat"
}

if (-not $SkipAnalyze) {
    if ($flutterExe) {
        Write-Host "`nRunning flutter analyze..." -ForegroundColor Cyan
        & $flutterExe analyze
        if ($LASTEXITCODE -eq 0) {
            Add-Pass "flutter analyze passed"
        } else {
            Add-Error "flutter analyze failed"
        }
    } else {
        Add-Error "Flutter was not found on PATH or at C:\src\flutter\bin\flutter.bat"
    }
}

$testFiles = @(Get-ChildItem -Path "test" -Recurse -Filter "*_test.dart" -ErrorAction SilentlyContinue)
if ($testFiles.Count -eq 0) {
    Add-Warning "No Flutter tests found yet"
} elseif (-not $SkipTests -and $flutterExe) {
    Write-Host "`nRunning flutter test..." -ForegroundColor Cyan
    & $flutterExe test
    if ($LASTEXITCODE -eq 0) {
        Add-Pass "flutter test passed"
    } else {
        Add-Error "flutter test failed"
    }
}

if ($CheckSupabase) {
    $supabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue
    $supabaseExe = if ($supabaseCommand) { $supabaseCommand.Source } else { $null }
    if (-not $supabaseExe -and (Test-Path -LiteralPath "$HOME\scoop\shims\supabase.exe")) {
        $supabaseExe = "$HOME\scoop\shims\supabase.exe"
    }

    if (-not $supabaseExe) {
        Add-Error "Supabase CLI was not found"
    } else {
        Write-Host "`nChecking deployed Supabase functions..." -ForegroundColor Cyan
        $functionList = (& $supabaseExe functions list --project-ref $SupabaseProjectRef 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            Add-Error "Could not list deployed Supabase functions"
        } else {
            @("strava-auth", "admin-growth-dashboard", "livekit-token") |
                ForEach-Object {
                    if ($functionList -match [regex]::Escape($_)) {
                        Add-Pass "Supabase function is deployed: $_"
                    } else {
                        Add-Error "Supabase function is missing: $_"
                    }
                }
        }
    }
}

$gitStatus = (& git status --porcelain 2>$null) -join "`n"
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    Add-Pass "Git working tree is clean"
} else {
    Add-Warning "Git working tree has uncommitted changes"
}

Write-Host "`nRelease preflight result: $($errors.Count) error(s), $($warnings.Count) warning(s)" -ForegroundColor Cyan
if ($errors.Count -gt 0) {
    exit 1
}
