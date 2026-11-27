# Cria a ponte persistente para a pasta do jogo (victory.toml + .victory-game-dir) e opcionalmente inicia Play-VIctory.cmd.
# Uso (inclusive com espacos no caminho):
#   powershell -ExecutionPolicy Bypass -File scripts\Link-Game.ps1 -Path "C:\jogos hidra\GTA6.Xbox.v1.0.2.1-CYBERLEEK" -Run
#   powershell -ExecutionPolicy Bypass -File scripts\Link-Game.ps1          # auto-detecta nos discos locais
param(
    [string]$Path = '',
    [ValidateSet('release', 'diag', 'safe')][string]$Mode = 'release',
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pointerFile = Join-Path $root '.victory-game-dir'
$tomlFile = Join-Path $root 'victory.toml'
$exampleToml = Join-Path $root 'victory.example.toml'

function Normalize-GameDir {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    $p = $Candidate.Trim().Trim('"').Trim("'")
    if ((Split-Path -Leaf $p) -ieq 'game_scarlett_master.exe') {
        $p = Split-Path -Parent $p
    }
    $exe = Join-Path $p 'game_scarlett_master.exe'
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        return (Resolve-Path -LiteralPath $p).Path
    }
    return $null
}

$gameDir = if ($Path) {
    $d = Normalize-GameDir $Path
    if (-not $d) { throw "game_scarlett_master.exe nao encontrado em: $Path" }
    $d
} else {
    $lines = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Resolve-GameExe.ps1') -Root $root
    $found = ($lines | Where-Object { $_ -like 'GAME_DIR=*' } | Select-Object -First 1)
    if (-not $found) { throw 'Nao foi possivel encontrar game_scarlett_master.exe automaticamente. Passe -Path "<pasta_do_jogo>".' }
    $found.Substring('GAME_DIR='.Length)
}

[System.IO.File]::WriteAllText($pointerFile, $gameDir + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

$escapedToml = $gameDir -replace "'", "''"
if (Test-Path -LiteralPath $tomlFile -PathType Leaf) {
    $raw = Get-Content -LiteralPath $tomlFile -Raw
    if ($raw -match "(?m)^game_dir\s*=.*$") {
        $raw = $raw -replace "(?m)^game_dir\s*=.*$", "game_dir = '$escapedToml'"
    } else {
        $raw = "[paths]`r`ngame_dir = '$escapedToml'`r`n" + $raw
    }
    [System.IO.File]::WriteAllText($tomlFile, $raw, [System.Text.UTF8Encoding]::new($false))
} elseif (Test-Path -LiteralPath $exampleToml -PathType Leaf) {
    $raw = Get-Content -LiteralPath $exampleToml -Raw
    $raw = $raw -replace "(?m)^game_dir\s*=.*$", "game_dir = '$escapedToml'"
    [System.IO.File]::WriteAllText($tomlFile, $raw, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "[VIctory] Ponte salva com sucesso!"
Write-Host "  Pasta do jogo: $gameDir"
Write-Host "  Executavel:    $(Join-Path $gameDir 'game_scarlett_master.exe')"
Write-Host "  Arquivos:      .victory-game-dir$(if (Test-Path $tomlFile) { ' e victory.toml' })"

if ($Run) {
    $cmd = Join-Path $root 'Play-VIctory.cmd'
    & cmd.exe /c "`"$cmd`" $Mode"
    exit $LASTEXITCODE
}
