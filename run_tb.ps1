param(
    [string]$tb
)

if (-not $tb) {
    Write-Host "Usage: .\run_tb.ps1 <testbench_top_module_name>"
    exit 1
}

# Collect all .v and .sv files in this folder
$srcFiles  = Get-ChildItem -Filter *.v  -ErrorAction SilentlyContinue
$srcFiles += Get-ChildItem -Filter *.sv -ErrorAction SilentlyContinue

if (-not $srcFiles) {
    Write-Host "No .v or .sv files found in current directory."
    exit 1
}

$src  = ($srcFiles | ForEach-Object { $_.Name }) -join " "
$out  = "sim_$tb.out"
$wave = "waves.vcd"

$cmd = "iverilog -g2012 -s $tb -o `"$out`" $src"
Write-Host ">> $cmd"
Invoke-Expression $cmd

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ">> vvp $out"
vvp $out

if (Test-Path $wave) {
    Write-Host ">> gtkwave $wave"
    gtkwave $wave
} else {
    Write-Host "No $wave produced (did you call `$dumpfile`/`$dumpvars` in $tb?)."
}
