# One-click test runner for the PurrPurrTown demo.
#
# Usage (from the project root):   .\tests\run_all.cmd
# Or with a custom Godot path:     .\tests\run_all.cmd -Godot 'D:\Godot\godot.exe'
#
# NOTE: This file is deliberately ASCII-only. Windows PowerShell 5.1 reads a
# .ps1 without a UTF-8 BOM as ANSI, which corrupts non-ASCII text and breaks
# parsing. Keep comments and strings in English here; the Chinese explanation
# lives in the project doc (运行与测试.md).
param(
    [string]$Godot = 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
)

# Project root = parent of the folder holding this script.
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
# Number of failed tasks, decides the exit code.
$failures = 0

# Fail fast if the engine is missing, instead of piling up confusing errors.
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host "Godot not found: $Godot" -ForegroundColor Red
    Write-Host "Pass the full godot.exe path with -Godot." -ForegroundColor Yellow
    exit 2
}

# Three headless tasks: trade unit tests, end-to-end flow test, main scene smoke run.
$tasks = @(
    @{ Name = 'trade unit tests'; Scene = 'res://tests/test_trade.tscn' },
    @{ Name = 'end-to-end flow test'; Scene = 'res://tests/test_flow.tscn' },
    @{ Name = 'main scene smoke (90 frames)'; Scene = $null }
)

foreach ($task in $tasks) {
    Write-Host ''
    Write-Host "=== $($task.Name) ===" -ForegroundColor Cyan
    # Capture the output into a variable through a pipeline: Godot is a windowed
    # program with no console, so PowerShell only waits for it (and sets
    # $LASTEXITCODE) when its output is piped. A plain assignment does not wait
    # and leaves $LASTEXITCODE empty.
    if ($task.Scene) {
        $output = (& $Godot --headless --path $ProjectRoot $task.Scene 2>&1 | Out-String)
    }
    else {
        $output = (& $Godot --headless --path $ProjectRoot --quit-after 90 2>&1 | Out-String)
    }
    # Save the exit code before printing anything else overwrites it.
    $code = $LASTEXITCODE
    # Print this run's output so a failed assertion is visible.
    Write-Host $output
    # Non-zero exit code means this task failed.
    if ($code -ne 0) {
        $failures++
        Write-Host "FAILED (exit code $code)" -ForegroundColor Red
    }
}

Write-Host ''
if ($failures -eq 0) {
    Write-Host 'All test tasks passed.' -ForegroundColor Green
    exit 0
}
Write-Host "$failures task(s) failed." -ForegroundColor Red
exit 1
