# Resolves the folder containing game_scarlett_master.exe and launch mode for Play-VIctory.cmd.
# Outputs ONLY KEY=VALUE lines on stdout so cmd.exe can parse paths containing spaces safely.
param(
    [string]$Root = '',
    [switch]$Interactive,
    [Parameter(ValueFromRemainingArguments)][string[]]$ArgsIn = @()
)

$ErrorActionPreference = 'SilentlyContinue'
if (-not $Root) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path
$pointerFile = Join-Path $Root '.victory-game-dir'
$tomlFile = Join-Path $Root 'victory.toml'

function Normalize-GameDir {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    $p = $Candidate.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ((Split-Path -Leaf $p) -ieq 'game_scarlett_master.exe') {
        $p = Split-Path -Parent $p
    }
    $exe = Join-Path $p 'game_scarlett_master.exe'
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        return (Resolve-Path -LiteralPath $p).Path
    }
    return $null
}

function Read-TomlGameDir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    foreach ($raw in (Get-Content -LiteralPath $Path)) {
        $line = $raw.Trim()
        if ($line.StartsWith('#') -or -not $line) { continue }
        if ($line -match "^game_dir\s*=\s*'([^']+)'") { return $matches[1] }
        if ($line -match '^game_dir\s*=\s*"([^"]+)"') { return ($matches[1] -replace '\\\\', '\') }
    }
    return $null
}

function Find-GameDirFast {
    param([string]$RepoRoot)
    $parent = Split-Path -Parent $RepoRoot
    if ($parent -and (Test-Path -LiteralPath $parent)) {
        foreach ($direct in @(
            $parent,
            (Join-Path $parent 'GTA6.Xbox.v1.0.2.1'),
            (Join-Path $parent 'GTA6.Xbox.v1.0.2.1-CYBERLEEK')
        )) {
            $hit = Normalize-GameDir $direct
            if ($hit) { return $hit }
        }
        try {
            foreach ($sub in [System.IO.Directory]::EnumerateDirectories($parent)) {
                $hit = Normalize-GameDir $sub
                if ($hit) { return $hit }
            }
        } catch {}
    }

    $skip = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in @('Windows', '$Recycle.Bin', '$WINDOWS.~BT', 'System Volume Information', 'ProgramData', 'Recovery', 'PerfLogs', 'MSOCache', 'Config.Msi', 'Program Files', 'Program Files (x86)', 'Users', 'Intel', 'AMD', 'NVIDIA', 'OneDriveTemp', 'Documents and Settings')) {
        $null = $skip.Add($s)
    }

    $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed -and $_.IsReady })
    foreach ($drive in $drives) {
        $rootPath = $drive.RootDirectory.FullName
        $hit = Normalize-GameDir $rootPath
        if ($hit) { return $hit }
        foreach ($hint in @('jogos hidra', 'Games', 'Jogos', 'Xbox', 'GTA6')) {
            $base = Join-Path $rootPath $hint
            if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
            $hit = Normalize-GameDir $base
            if ($hit) { return $hit }
            try {
                foreach ($d2 in [System.IO.Directory]::EnumerateDirectories($base)) {
                    $hit = Normalize-GameDir $d2
                    if ($hit) { return $hit }
                }
            } catch {}
        }
    }

    foreach ($drive in $drives) {
        $rootPath = $drive.RootDirectory.FullName
        $lvl1 = @()
        try {
            $lvl1 = [System.IO.Directory]::EnumerateDirectories($rootPath)
        } catch { continue }
        foreach ($d1 in $lvl1) {
            $name1 = [System.IO.Path]::GetFileName($d1)
            if ($skip.Contains($name1) -or $name1.StartsWith('.')) { continue }
            $hit = Normalize-GameDir $d1
            if ($hit) { return $hit }
            try {
                foreach ($d2 in [System.IO.Directory]::EnumerateDirectories($d1)) {
                    $hit = Normalize-GameDir $d2
                    if ($hit) { return $hit }
                }
            } catch {}
        }
    }
    return $null
}

function Save-Pointer {
    param([string]$Dir)
    if (-not $Dir) { return }
    try {
        [System.IO.File]::WriteAllText($pointerFile, $Dir + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    } catch {}
}

$mode = 'release'
$argDir = $null
foreach ($a in (@($env:V_ARG1, $env:V_ARG2) + @($ArgsIn))) {
    if ([string]::IsNullOrWhiteSpace($a)) { continue }
    $clean = $a.Trim().Trim('"')
    if ($clean -ieq 'diag' -or $clean -ieq 'safe' -or $clean -ieq 'release') {
        $mode = $clean.ToLowerInvariant()
        continue
    }
    $resolved = Normalize-GameDir $clean
    if ($resolved) {
        $argDir = $resolved
        Save-Pointer $resolved
    }
}

$gameDir = $argDir
if (-not $gameDir -and $env:VICTORY_GAME_DIR) {
    $gameDir = Normalize-GameDir $env:VICTORY_GAME_DIR
}
if (-not $gameDir -and (Test-Path -LiteralPath $pointerFile -PathType Leaf)) {
    $gameDir = Normalize-GameDir (Get-Content -LiteralPath $pointerFile -TotalCount 1)
}
if (-not $gameDir) {
    $gameDir = Normalize-GameDir (Read-TomlGameDir $tomlFile)
}
if (-not $gameDir) {
    $gameDir = Find-GameDirFast $Root
    if ($gameDir) { Save-Pointer $gameDir }
}
if (-not $gameDir -and $Interactive -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    [Console]::Error.WriteLine('[VIctory] game_scarlett_master.exe nao foi encontrado automaticamente.')
    [Console]::Error.Write('[VIctory] Cole o caminho da pasta do jogo (ou do .exe) e aperte Enter: ')
    $typed = [Console]::In.ReadLine()
    $gameDir = Normalize-GameDir $typed
    if ($gameDir) { Save-Pointer $gameDir }
}

[Console]::Out.WriteLine("MODE=$mode")
if ($gameDir) {
    [Console]::Out.WriteLine("GAME_DIR=$gameDir")
    exit 0
}
exit 2
