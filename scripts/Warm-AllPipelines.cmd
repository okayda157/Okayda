@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not defined VICTORY_CACHE_DIR set "VICTORY_CACHE_DIR=%LOCALAPPDATA%\VIctory\cache-amd"
if not defined VICTORY_GAME_DIR (
  if exist "%~dp0..\..\GTA6.Xbox.v1.0.2.1\game_scarlett_master.exe" (
    set "VICTORY_GAME_DIR=%~dp0..\..\GTA6.Xbox.v1.0.2.1"
  )
)
if not defined VICTORY_PORT_CBV set "VICTORY_PORT_CBV=1"
set "runner=%~dp0..\target\release\victory.exe"
if not exist "%runner%" set "runner=%~dp0..\target\diag\victory.exe"
if not exist "%runner%" (
  echo Build primeiro: cargo build --release --locked -p victory
  exit /b 2
)
if exist "%VICTORY_GAME_DIR%\game_scarlett_master.exe" (
  echo [1/3] Traduzindo shaders do jogo em "%VICTORY_CACHE_DIR%" ^(CBV=%VICTORY_PORT_CBV%^)...
  "%runner%" shaders "%VICTORY_GAME_DIR%\game_scarlett_master.exe" "%VICTORY_GAME_DIR%\shaders.rpf" "%VICTORY_GAME_DIR%\XboxBvhBuilder.dll" "%VICTORY_GAME_DIR%\amd_fidelityfx_upscaler_xbox.dll" --jobs 8
)
echo [2/3] Priorizando pipelines ja usados em gameplay ^(early-pipelines.txt^)...
"%runner%" warm --used --jobs 6
echo [3/3] Pre-compilando pipelines restantes de "%VICTORY_CACHE_DIR%" ^(pode fechar e continuar depois^)...
"%runner%" warm --jobs 6
echo Concluido.
pause
