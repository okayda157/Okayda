# Ensures victory.exe and D3D12\D3D12Core.dll (Agility SDK 1.620) exist for Play-VIctory.cmd.
# Order: local binaries -> GitHub Release auto-download -> local cargo build -> D3D12Core.dll fallback.
# Outputs ONLY KEY=VALUE lines on stdout so cmd.exe can parse paths safely.
param(
    [string]$Root = '',
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
if (-not $Root) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path
$ReleaseUrl = 'https://github.com/okayda157/Okayda/releases/latest/download/Okayda-win64-release.zip'
$AgilityUrl = 'https://api.nuget.org/v3-flatcontainer/microsoft.direct3d.d3d12/1.620.2/microsoft.direct3d.d3d12.1.620.2.nupkg'

function Find-Runner {
    param([string]$Base, [string]$M)
    $candidates = if ($M -ieq 'diag') {
        @(
            (Join-Path $Base 'target\diag\victory.exe'),
            (Join-Path $Base 'victory-diag.exe')
        )
    } else {
        @(
            (Join-Path $Base 'target\release\victory.exe'),
            (Join-Path $Base 'victory.exe'),
            (Join-Path $Base 'bin\victory.exe'),
            (Join-Path $Base 'target\diag\victory.exe')
        )
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }
    return $null
}

function Ensure-D3D12 {
    param([string]$RunnerPath, [string]$Base, [bool]$NeedDebug)
    $runnerDir = Split-Path -Parent $RunnerPath
    $d3dDir = Join-Path $runnerDir 'D3D12'
    $coreDll = Join-Path $d3dDir 'D3D12Core.dll'
    if (Test-Path -LiteralPath $coreDll -PathType Leaf) {
        if (-not $NeedDebug -or (Test-Path -LiteralPath (Join-Path $d3dDir 'd3d12SDKLayers.dll') -PathType Leaf)) {
            return
        }
    }
    New-Item -ItemType Directory -Force -Path $d3dDir | Out-Null
    foreach ($localSrc in @((Join-Path $Base 'D3D12'), (Join-Path $Base 'target\release\D3D12'), (Join-Path $Base 'target\diag\D3D12'))) {
        $cand = Join-Path $localSrc 'D3D12Core.dll'
        if (Test-Path -LiteralPath $cand -PathType Leaf) {
            Copy-Item -Force -LiteralPath $cand -Destination $coreDll
            $layers = Join-Path $localSrc 'd3d12SDKLayers.dll'
            if ($NeedDebug -and (Test-Path -LiteralPath $layers -PathType Leaf)) {
                Copy-Item -Force -LiteralPath $layers -Destination (Join-Path $d3dDir 'd3d12SDKLayers.dll')
            }
            return
        }
    }

    [Console]::Error.WriteLine('[VIctory] Baixando D3D12 Agility SDK 1.620.2 oficial da Microsoft...')
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("victory-agility-" + [guid]::NewGuid().ToString('N'))
    $nupkg = Join-Path $tmpDir 'agility.zip'
    try {
        New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $AgilityUrl -OutFile $nupkg -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $nupkg -DestinationPath $tmpDir -Force
        $srcCore = Join-Path $tmpDir 'build\native\bin\x64\D3D12Core.dll'
        if (Test-Path -LiteralPath $srcCore -PathType Leaf) {
            Copy-Item -Force -LiteralPath $srcCore -Destination $coreDll
        }
        $srcLayers = Join-Path $tmpDir 'build\native\bin\x64\d3d12SDKLayers.dll'
        if ($NeedDebug -and (Test-Path -LiteralPath $srcLayers -PathType Leaf)) {
            Copy-Item -Force -LiteralPath $srcLayers -Destination (Join-Path $d3dDir 'd3d12SDKLayers.dll')
        }
    } catch {
        [Console]::Error.WriteLine("[VIctory] Aviso: nao foi possivel baixar D3D12Core.dll ($($_.Exception.Message)).")
    } finally {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmpDir
    }
}

$runner = Find-Runner $Root $Mode

if (-not $runner -and $Mode -ine 'diag') {
    $destDir = Join-Path $Root 'target\release'
    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("okayda-release-" + [guid]::NewGuid().ToString('N') + '.zip')
    try {
        [Console]::Error.WriteLine('[VIctory] Executavel nao encontrado localmente; tentando baixar da Release no GitHub...')
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ReleaseUrl -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Expand-Archive -Path $tmpZip -DestinationPath $destDir -Force
        $runner = Find-Runner $Root $Mode
    } catch {
        [Console]::Error.WriteLine("[VIctory] Release pre-compilada indisponivel ($($_.Exception.Message)).")
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpZip
    }
}

if (-not $runner) {
    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    if ($cargo) {
        [Console]::Error.WriteLine("[VIctory] Compilando $Mode via cargo (primeira vez pode levar alguns minutos)...")
        Push-Location $Root
        try {
            $cargoCmd = if ($Mode -ieq 'diag') {
                'cargo build --profile diag --locked -p victory --features diagnostics 1>&2'
            } else {
                'cargo build --release --locked -p victory 1>&2'
            }
            & cmd.exe /c $cargoCmd
            if ($LASTEXITCODE -eq 0) {
                $runner = Find-Runner $Root $Mode
            }
        } finally {
            Pop-Location
        }
    }
}

if (-not $runner) {
    [Console]::Error.WriteLine("[VIctory] Nao foi possivel obter victory.exe em: $Root")
    [Console]::Error.WriteLine('[VIctory] Baixe Okayda-win64-release.zip em https://github.com/okayda157/Okayda/releases ou instale Rust e rode: cargo build --release --locked -p victory')
    exit 2
}

Ensure-D3D12 -RunnerPath $runner -Base $Root -NeedDebug:($Mode -ieq 'diag')
[Console]::Out.WriteLine("RUNNER=$runner")
exit 0
