# Runs the headless test suite and prints the report.
#
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -SkipImport
#
# Two steps, both required:
#
#   1. Import/scan pass (`--import`) — registers global class names in
#      .godot/global_script_class_cache.cfg and reports parse errors in every
#      script. Without it, a fresh clone cannot resolve `class_name` types and
#      headless runs fail with confusing "Could not find type" errors.
#   2. Test run — TestRunner.tscn writes tests/results/last_run.md and sets the
#      exit code.
#
# Godot's Windows build is a GUI-subsystem executable, so it is launched through
# Start-Process -NoNewWindow -Wait: that attaches its stdout to this console AND
# gives us a reliable exit code (a plain & call returns before the game exits).
#
# Exit codes: 0 = all green, 1 = failures, 2 = watchdog timeout, 3 = setup error.

param(
    [string]$GodotExe = "E:\GAMES\Godot_v4.7-stable_win64.exe",
    [switch]$SkipImport,
    [switch]$ShowLog
)

$ErrorActionPreference = "Stop"

# The report and logs are UTF-8; without this, non-ASCII characters print as mojibake.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportPath = Join-Path $PSScriptRoot "results\last_run.md"
$logPath = Join-Path $env:APPDATA "Godot\app_userdata\Tower Battle Royal\logs\godot.log"

if (-not (Test-Path $GodotExe)) {
    Write-Host "Godot executable not found: $GodotExe" -ForegroundColor Red
    Write-Host "Pass -GodotExe '<path to Godot 4.7>' to use a different build."
    exit 3
}

Write-Host "Project : $projectRoot"
Write-Host "Engine  : $GodotExe"

if (-not $SkipImport) {
    Write-Host ""
    Write-Host "Step 1/2 - importing (registers global classes, reports parse errors)..." -ForegroundColor Cyan
    $importArgs = '--headless --quiet --path "' + $projectRoot + '" --import'
    $import = Start-Process -FilePath $GodotExe -ArgumentList $importArgs -Wait -PassThru -NoNewWindow
    Write-Host "  import exit code: $($import.ExitCode)"
}

Write-Host ""
Write-Host "Step 2/2 - running headless tests..." -ForegroundColor Cyan
if (Test-Path $reportPath) {
    Remove-Item $reportPath -Force
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$testArgs = '--headless --path "' + $projectRoot + '" res://tests/TestRunner.tscn'
$test = Start-Process -FilePath $GodotExe -ArgumentList $testArgs -Wait -PassThru -NoNewWindow
$stopwatch.Stop()

Write-Host ""
if (Test-Path $reportPath) {
    Get-Content $reportPath
} else {
    Write-Host "No report was written - the engine failed before finishing." -ForegroundColor Red
}
Write-Host ("Wall clock: {0:N1}s | engine exit code: {1}" -f $stopwatch.Elapsed.TotalSeconds, $test.ExitCode)

if ($ShowLog -or -not (Test-Path $reportPath)) {
    Write-Host ""
    Write-Host "Last 60 error/warning lines from the engine log:" -ForegroundColor Yellow
    if (Test-Path $logPath) {
        Select-String -Path $logPath -Pattern 'ERROR|WARNING|Parse Error|SCRIPT ERROR' |
            Select-Object -Last 60 | ForEach-Object { $_.Line }
    } else {
        Write-Host "  (no engine log at $logPath)"
    }
}

exit $test.ExitCode
