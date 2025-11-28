param(
    [string]$tb
)

$env:Path += ";C:\iverilog\bin"

if (-not $tb) {
    Write-Host "Usage: .\run_tb.ps1 <testbench_top_module_name>"
    exit 1
}

# Root folder where this script lives
$root = $PSScriptRoot

# === Ensure sim/ exists ===
$simDir = Join-Path $root "sim"
if (-not (Test-Path $simDir)) {
    New-Item -ItemType Directory -Path $simDir | Out-Null
}

# Collect all .v and .sv files in src/ and tb/ under the root
$searchPath = @(
    (Join-Path $root "src")
    (Join-Path $root "tb")
)

$srcFiles = Get-ChildItem -Path $searchPath -Include *.v,*.sv -File -Recurse -ErrorAction SilentlyContinue

if (-not $srcFiles) {
    Write-Host "No .v or .sv files found under src/ or tb/."
    exit 1
}

# Build a quoted list of full paths (handles spaces in path names)
$src  = ($srcFiles | ForEach-Object { '"' + $_.FullName + '"' }) -join " "

# Put sim binary & waves in sim/
$out  = Join-Path $simDir ("sim_{0}.out" -f $tb)
$wave = Join-Path $simDir "waves.vcd"

$cmd = "iverilog -g2012 -s $tb -o `"$out`" $src"
Write-Host ">> $cmd"
Invoke-Expression $cmd

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ">> vvp $out"
vvp $out

if (Test-Path $wave) {
    Write-Host ">> opening $wave in GTKWave"

    # FULL PATH TO gtkwave.exe —> change this to your actual install path if needed
    $gtkwaveExe = "C:\iverilog\gtkwave\bin\gtkwave.exe"

    if (Test-Path $gtkwaveExe) {
        & "$gtkwaveExe" $wave
    } else {
        Write-Host "Cannot find gtkwave at $gtkwaveExe. Open $wave manually in GTKWave."
    }
} else {
    Write-Host "No $wave produced (did you call `\$dumpfile`/`\$dumpvars` in $tb, with path matching sim/waves.vcd?)."
}
