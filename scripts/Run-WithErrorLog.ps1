# Error-reporting runner for VIctory-Belobug-AMD-a-publier
param(
    [Parameter(Mandatory)][string]$Runner,
    [Parameter(Mandatory)][string]$GameExe,
    [string]$Console = 'series-s',
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$rawLog = Join-Path $logDir "sessao-$ts.log"
$rawErr = Join-Path $logDir "sessao-$ts.err.log"
$reportPath = Join-Path $logDir "relatorio-$ts.txt"
$latestReport = Join-Path $logDir 'ULTIMO-RELATORIO.txt'
$latestLog = Join-Path $logDir 'ULTIMA-SESSAO.log'

$crashesFile = Join-Path $env:LOCALAPPDATA 'victory\data\7952987A\crashes.log'
$crashesBefore = if (Test-Path $crashesFile) { (Get-Item $crashesFile).Length } else { 0 }
$startedAt = Get-Date

Write-Host "[VIctory] Modo=$Mode | Bin=$Runner"
Write-Host "[VIctory] Logs desta sessao: $rawLog"
Write-Host "[VIctory] Relatorio automatico: $latestReport"

$GameExeClean = $GameExe.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $GameExeClean -PathType Leaf)) {
    Write-Error "Executavel do jogo nao encontrado: $GameExeClean"
    exit 2
}
$QuotedGameExe = '"' + $GameExeClean + '"'

$p = Start-Process -FilePath $Runner `
    -ArgumentList @('run', $QuotedGameExe, '--console', $Console, '--execute') `
    -WorkingDirectory $root `
    -WindowStyle Normal `
    -RedirectStandardOutput $rawLog `
    -RedirectStandardError $rawErr `
    -PassThru

# Hold process handle so ExitCode is always populated reliably after WaitForExit.
$null = $p.Handle
$p.WaitForExit()
$exitCode = [int]$p.ExitCode
$endedAt = Get-Date
$dur = [math]::Round(($endedAt - $startedAt).TotalSeconds, 1)

$combined = @()
if (Test-Path $rawLog) { $combined += Get-Content $rawLog -ErrorAction SilentlyContinue }
if (Test-Path $rawErr) {
    $combined += '=== STDERR / ENGINE LOG ==='
    $combined += Get-Content $rawErr -ErrorAction SilentlyContinue
}
Set-Content -Path $rawLog -Value $combined -Encoding UTF8
Remove-Item $rawErr -Force -ErrorAction SilentlyContinue
Copy-Item -Force $rawLog $latestLog -ErrorAction SilentlyContinue

$newCrashText = @()
if (Test-Path $crashesFile) {
    $afterLen = (Get-Item $crashesFile).Length
    if ($afterLen -gt $crashesBefore) {
        $fs = [System.IO.File]::Open($crashesFile, 'Open', 'Read', 'ReadWrite')
        try {
            $fs.Seek($crashesBefore, 'Begin') | Out-Null
            $sr = New-Object System.IO.StreamReader($fs)
            $newCrashText = ($sr.ReadToEnd()) -split "`r?`n" | Where-Object { $_ -ne '' }
        } finally {
            $fs.Dispose()
        }
    }
}

$tempCrashDir = Join-Path $env:LOCALAPPDATA 'victory\data\7952987A\temp'
$newCrashFiles = Get-ChildItem $tempCrashDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $startedAt -and ($_.Extension -in @('.log', '.dmp')) }

$winEvents = Get-WinEvent -LogName Application,System,'Microsoft-Windows-Resource-Exhaustion-Detector/Operational' -MaxEvents 40 -ErrorAction SilentlyContinue |
    Where-Object { $_.TimeCreated -ge $startedAt.AddSeconds(-5) -and ($_.Id -in @(1000,1003,2004,4101,4109) -or $_.ProviderName -match 'Display|Application Error|Exhaustion') }

$lines = Get-Content $rawLog -ErrorAction SilentlyContinue
$grep = {
    param([string]$pattern, [int]$max = 50)
    @($lines | Where-Object { $_ -match $pattern } | Select-Object -First $max)
}

$secCrash = @()
if ($newCrashText.Count -gt 0) { $secCrash += $newCrashText }
$secCrash += & $grep 'unhandled exception|0xc0000|panic|fatal|abort| ERROR |driver''s compiler crashed' 40
if ($newCrashFiles) { $secCrash += ($newCrashFiles | ForEach-Object { "Dump/Crash: $($_.FullName) ($($_.Length) B)" }) }
$secCrash += @($winEvents | Where-Object { $_.Id -eq 1000 } | ForEach-Object { "WinEvent 1000 ($($_.TimeCreated)): $($_.Message -replace '\r?\n',' ')" })

$secBlack = & $grep 'device removed|0x887A000[567]|no host list|TdrDelay|TDR|frame is black|black screen|CreateSwapChain.*fail|failed to present|DRED' 40
$secBlack += @($winEvents | Where-Object { $_.Id -in @(4101,4109) } | ForEach-Object { "Display/TDR $($_.Id) ($($_.TimeCreated)): $($_.Message -replace '\r?\n',' ')" })

$secStutter = & $grep 'host memory pressure|critical_commit|E_OUTOFMEMORY|hung for|slow|without a host pipeline|wait budget|changed the budget|commit headroom' 40
$secStutter += @($lines | Where-Object { $_ -match '([1-9]\d{2,}\.\d+)\s*ms/frame' } | Select-Object -First 20)
$secStutter += @($winEvents | Where-Object { $_.Id -in @(1003,2004) } | ForEach-Object { "MemExhaust $($_.Id) ($($_.TimeCreated)): $($_.Message -replace '\r?\n',' ')" })

$secTex = & $grep 'passed over unmapped|waiting=[1-9]|card has no room|no room for more|texture.*fail|dstorage.*err|textures.*refused|missing.*texture|staging.*deferred' 40
$secShd = & $grep 'misses=[1-9]|do not translate|without a host pipeline|dropped [1-9]|not implemented.*pipeline|shader.*fail|shader.*error|DeserializeComputePipelineStateX' 40

$exitHex = ('0x{0:X8}' -f ($exitCode -band 0xFFFFFFFF))
$secClose = @("ExitCode=$exitCode ($exitHex) | Duracao=${dur}s")
if ($exitCode -ne 0) {
    $secClose += 'ALERTA: Encerramento inesperado (ExitCode != 0).'
} elseif ($newCrashText.Count -gt 0 -or $secBlack.Count -gt 0) {
    $secClose += 'ALERTA: Falha grave detectada no log antes do encerramento.'
} else {
    $secClose += 'Encerramento limpo (ExitCode=0).'
}

$report = @(
    "=== RELATORIO DE DIAGNOSTICO VICTORY ($ts) ==="
    "Executavel: $Runner"
    "Modo: $Mode | Console: $Console | Inicio: $startedAt | Fim: $endedAt | Duracao: ${dur}s"
    "Log completo: $rawLog"
    ""
    "[1. CRASHES / EXCECOES]"
    $(if ($secCrash.Count -gt 0) { $secCrash } else { '(nenhum)' })
    ""
    "[2. TELA PRETA / GPU DEVICE REMOVED / TDR]"
    $(if ($secBlack.Count -gt 0) { $secBlack } else { '(nenhum)' })
    ""
    "[3. TRAVAMENTOS / STUTTERS / MEMORIA]"
    $(if ($secStutter.Count -gt 0) { $secStutter } else { '(nenhum)' })
    ""
    "[4. FALTA DE TEXTURA]"
    $(if ($secTex.Count -gt 0) { $secTex } else { '(nenhum)' })
    ""
    "[5. FALTA DE SHADERS / PIPELINES]"
    $(if ($secShd.Count -gt 0) { $secShd } else { '(nenhum)' })
    ""
    "[6. FECHAMENTOS INESPERADOS]"
    $secClose
)

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Copy-Item -Force $reportPath $latestReport -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== RESUMO DA SESSAO (${dur}s, ExitCode=$exitCode / $exitHex) ==="
Write-Host "Relatorio salvo em: $reportPath"
if ($exitCode -ne 0 -or $secCrash.Count -gt 0 -or $secBlack.Count -gt 0) {
    Write-Host "Houve falha/fechamento! Abra: $latestReport" -ForegroundColor Red
}
exit $exitCode
