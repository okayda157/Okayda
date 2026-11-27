@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "root=%~dp0"
if "%root:~-1%"=="\" set "root=%root:~0,-1%"

:: Resolve modo (release/diag/safe) e pasta do jogo automaticamente:
:: 1) Pasta/exe arrastado ou passado como argumento
:: 2) Variavel VICTORY_GAME_DIR
:: 3) Arquivo local .victory-game-dir ou victory.toml ([paths] game_dir)
:: 4) Varredura rapida nas pastas vizinhas e discos locais (com suporte a espacos)
set "mode=release"
set "resolved_dir="
set "V_ARG1=%~1"
set "V_ARG2=%~2"
for /f "usebackq tokens=1* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%root%\scripts\Resolve-GameExe.ps1" -Root "%root%" -Interactive`) do (
  if /i "%%A"=="MODE" set "mode=%%B"
  if /i "%%A"=="GAME_DIR" set "resolved_dir=%%B"
)
set "V_ARG1="
set "V_ARG2="
if defined resolved_dir set "VICTORY_GAME_DIR=%resolved_dir%"
if not defined VICTORY_GAME_DIR set "VICTORY_GAME_DIR=%root%\..\GTA6.Xbox.v1.0.2.1"
if not exist "%VICTORY_GAME_DIR%\game_scarlett_master.exe" (
  echo Nao foi possivel localizar game_scarlett_master.exe. 1>&2
  echo Use: powershell -ExecutionPolicy Bypass -File scripts\Link-Game.ps1 -Path "C:\pasta\do\jogo" -Run 1>&2
  echo Ou defina VICTORY_GAME_DIR / arraste a pasta do jogo sobre Play-VIctory.cmd. 1>&2
  exit /b 2
)

if /i "%mode%"=="diag" (
  set "runner=%~dp0target\diag\victory.exe"
) else (
  set "runner=%~dp0target\release\victory.exe"
  if not exist "%runner%" set "runner=%~dp0target\diag\victory.exe"
)
if not exist "%runner%" (
  echo Build primeiro: cargo build --release --locked -p victory
  exit /b 2
)

:: Cache isolado desta build AMD (versionado, compativel com VICTORY_PORT_CBV=1)
if not defined VICTORY_CACHE_DIR set "VICTORY_CACHE_DIR=%LOCALAPPDATA%\VIctory\cache-amd"

:: HUD grafico ao vivo (F3 alterna) + gravacao dos pipelines usados para Warm-AllPipelines.cmd
if not defined VICTORY_PANEL set "VICTORY_PANEL=1"
if not defined VICTORY_PIPELINE_BOOK set "VICTORY_PIPELINE_BOOK=1"

:: Dedicacao maxima segura na RX 6600 (8 GB GDDR6) mantendo margem anti-spill e RAM enxuta em 16 GB PC
if not defined VICTORY_MEMORY_CARD_MB set "VICTORY_MEMORY_CARD_MB=2048"
if not defined VICTORY_VRAM_RESERVE_MB set "VICTORY_VRAM_RESERVE_MB=2048"
if not defined VICTORY_CARD_BUFFERS set "VICTORY_CARD_BUFFERS=1"
if not defined VICTORY_CARD_BUFFERS_MIN_KB set "VICTORY_CARD_BUFFERS_MIN_KB=128"
if not defined VICTORY_CARD_BUFFERS_MB set "VICTORY_CARD_BUFFERS_MB=1024"
if not defined VICTORY_CARD_WINDOWS_MB set "VICTORY_CARD_WINDOWS_MB=0"
if not defined VICTORY_WINDOW_BUDGET_MB set "VICTORY_WINDOW_BUDGET_MB=1024"
if not defined VICTORY_CARD_ROOM_FOR_BUFFERS set "VICTORY_CARD_ROOM_FOR_BUFFERS=1"
if not defined VICTORY_CARD_ROOM_FOR_TARGETS_MB set "VICTORY_CARD_ROOM_FOR_TARGETS_MB=1536"
if not defined VICTORY_TEXTURE_ROOM_PERCENT set "VICTORY_TEXTURE_ROOM_PERCENT=85"
if not defined VICTORY_VRAM_TARGET_PERCENT set "VICTORY_VRAM_TARGET_PERCENT=84"
if not defined VICTORY_VRAM_EVICT_PERCENT set "VICTORY_VRAM_EVICT_PERCENT=88"
if not defined VICTORY_POOL_KEEP_PERCENT set "VICTORY_POOL_KEEP_PERCENT=82"
if not defined VICTORY_POOL_SPARES_MAX set "VICTORY_POOL_SPARES_MAX=6"
if not defined VICTORY_STAGING_KEPT set "VICTORY_STAGING_KEPT=2"
if not defined VICTORY_SCRATCH_KEPT_MB set "VICTORY_SCRATCH_KEPT_MB=64"
if not defined VICTORY_SNAPSHOT_POOL_MB set "VICTORY_SNAPSHOT_POOL_MB=96"
if not defined VICTORY_LIST_POOL_MAX set "VICTORY_LIST_POOL_MAX=96"
if not defined VICTORY_BURY_LAG set "VICTORY_BURY_LAG=12"
if not defined VICTORY_RIPE_BLOCKS set "VICTORY_RIPE_BLOCKS=4"

:: Sem limitadores de upload/prefetch; destrava threads no Xeon 10c/20t mantendo staging enxuto
if not defined VICTORY_RESIDENCY set "VICTORY_RESIDENCY=0"
if not defined VICTORY_TEXTURE_CATCHUP set "VICTORY_TEXTURE_CATCHUP=1"
if not defined VICTORY_TEXTURE_STAGE_MB set "VICTORY_TEXTURE_STAGE_MB=256"
if not defined VICTORY_PIPELINE_WORKERS set "VICTORY_PIPELINE_WORKERS=6"
if not defined VICTORY_THIN_THREADS set "VICTORY_THIN_THREADS=10"
if not defined VICTORY_UNDER_THREADS set "VICTORY_UNDER_THREADS=8"
if not defined VICTORY_VIEW_THREADS set "VICTORY_VIEW_THREADS=8"
if not defined VICTORY_LAND_THREADS set "VICTORY_LAND_THREADS=10"
if not defined VICTORY_FAST_CORES set "VICTORY_FAST_CORES=0"

:: Aceleracao completa na GPU (compute offload + async submit, write-watch antecipado, sem stage 2 bloated L0)
if not defined VICTORY_ASYNC_SUBMIT set "VICTORY_ASYNC_SUBMIT=1"
if not defined VICTORY_ASK_EARLY set "VICTORY_ASK_EARLY=4"
if not defined VICTORY_TEXTURE_NO_WAIT set "VICTORY_TEXTURE_NO_WAIT=1"
if not defined VICTORY_RELAY set "VICTORY_RELAY=2"
if not defined VICTORY_WIDE_BACK set "VICTORY_WIDE_BACK=1"
if not defined VICTORY_CARD_REHASH_RUNS set "VICTORY_CARD_REHASH_RUNS=1"
if not defined VICTORY_JOIN_COPIES set "VICTORY_JOIN_COPIES=1"
if not defined VICTORY_INDIRECT_WINDOW set "VICTORY_INDIRECT_WINDOW=1"
if not defined VICTORY_RELAY_COPY set "VICTORY_RELAY_COPY=1"
if not defined VICTORY_CARD_STEPS set "VICTORY_CARD_STEPS=1"
if not defined VICTORY_INDIRECT_BATCH set "VICTORY_INDIRECT_BATCH=2"
if not defined VICTORY_MAP_THREADS set "VICTORY_MAP_THREADS=1"
if not defined VICTORY_TITLE_PRIORITIES set "VICTORY_TITLE_PRIORITIES=0"
if not defined VICTORY_CARD_AWAKE set "VICTORY_CARD_AWAKE=1"
if not defined VICTORY_SHOW_AFTER set "VICTORY_SHOW_AFTER=1"
if not defined VICTORY_THIN set "VICTORY_THIN=1"
if not defined VICTORY_JOIN_PARTS set "VICTORY_JOIN_PARTS=8"
if not defined VICTORY_UPLOAD_AHEAD set "VICTORY_UPLOAD_AHEAD=1"

:: Iluminacao ambiente + sombras limpas (remove manchas brancas em interiores, rostos pretos e neblina de ceu dentro de comodos)
if not defined VICTORY_AMBIENT set "VICTORY_AMBIENT=1.0"
if not defined VICTORY_AMBIENT_SHADE set "VICTORY_AMBIENT_SHADE=0.55,0.45"
if not defined VICTORY_AMBIENT_AIR set "VICTORY_AMBIENT_AIR=1.2"
if not defined VICTORY_AMBIENT_CAP set "VICTORY_AMBIENT_CAP=1.55"
if not defined VICTORY_AMBIENT_KEEP set "VICTORY_AMBIENT_KEEP=0.55"
if not defined VICTORY_AMBIENT_FLOOR set "VICTORY_AMBIENT_FLOOR=0.045"
if not defined VICTORY_AMBIENT_SETTLE set "VICTORY_AMBIENT_SETTLE=250,3,2.0"

:: Renderer ports da build AMD (em "safe", desliga os 4 experimentais mantendo CBV + VRAM)
if /i "%mode%"=="safe" (
  if not defined VICTORY_PORT_CBV set "VICTORY_PORT_CBV=1"
) else (
  if not defined VICTORY_PORT_CONSTANTS set "VICTORY_PORT_CONSTANTS=1"
  if not defined VICTORY_PORT_DESCRIPTORS set "VICTORY_PORT_DESCRIPTORS=1"
  if not defined VICTORY_PORT_CBV set "VICTORY_PORT_CBV=1"
  if not defined VICTORY_PORT_GUARD set "VICTORY_PORT_GUARD=1"
  if not defined VICTORY_PORT_JOURNAL set "VICTORY_PORT_JOURNAL=1"
)
:: Resolucao alvo ~30 FPS na RX 6600 (720p externo + upscaler nativo 0.85x = ~1088x612 interno, HUD 720p)
if not defined VICTORY_OUTPUT set "VICTORY_OUTPUT=1280x720"
if not defined VICTORY_UPSCALER set "VICTORY_UPSCALER=6"
if not defined VICTORY_RENDER_SCALE set "VICTORY_RENDER_SCALE=0.85"
if not defined VICTORY_FRAME_INTERVAL_MS set "VICTORY_FRAME_INTERVAL_MS=16.667"
if /i "%mode%"=="diag" if not defined VICTORY_D3D12_DRED set "VICTORY_D3D12_DRED=light"

:: Logs direcionados para pasta logs\ sem flood per-draw nem 120k WARNs de port_descriptors
if not defined VICTORY_LOG if not defined RUST_LOG set "VICTORY_LOG=warn,victory_gpu::port_descriptors=error,victory_gpu::host=info,victory_gpu::queue=info,victory_gpu::shadow=info,victory_gpu::pipeline=info,victory_gpu::texture=info,victory_gpu::resource=info,victory_gpu::ambient=info"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Run-WithErrorLog.ps1" -Runner "%runner%" -GameExe "%VICTORY_GAME_DIR%\game_scarlett_master.exe" -Console "series-s" -Mode "%mode%"
set "rc=%errorlevel%"
if %rc% neq 0 pause
exit /b %rc%
