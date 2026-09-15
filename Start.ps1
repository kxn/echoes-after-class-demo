param([switch]$Editor, [switch]$Test)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engine)) {
    $installedEngine = Get-Command godot -ErrorAction SilentlyContinue
    if ($installedEngine) { $engine = $installedEngine.Source }
    else { throw 'Open project.godot with Godot 4.3 or newer (standard edition), then press F6.' }
}
if ($Test) {
    & $engine --headless --path $projectRoot -- --test
} elseif ($Editor) {
    Start-Process -FilePath $engine -ArgumentList @('--editor', '--path', ('"' + $projectRoot + '"'))
} else {
    Start-Process -FilePath $engine -ArgumentList @('--path', ('"' + $projectRoot + '"'), '--maximized')
}
