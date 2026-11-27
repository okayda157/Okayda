@echo off
setlocal
:: Run as Administrator to raise C:\pagefile.sys (SSD) to 24 GB initial / 40 GB max
:: Total virtual commit becomes ~40 GB initial / ~56 GB max (16 GB RAM + 24..40 GB pagefile).
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permissao de Administrador para ajustar a memoria virtual...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cs = Get-CimInstance Win32_ComputerSystem; if ($cs.AutomaticManagedPagefile) { Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile=$false} }; ^
   $pf = Get-CimInstance Win32_PageFileSetting | Where-Object { $_.Name -ieq 'C:\pagefile.sys' }; ^
   if ($pf) { Set-CimInstance -InputObject $pf -Property @{InitialSize=24576; MaximumSize=40960} } ^
   else { New-CimInstance -ClassName Win32_PageFileSetting -Property @{Name='C:\pagefile.sys'; InitialSize=24576; MaximumSize=40960} | Out-Null }; ^
   Get-CimInstance Win32_PageFileSetting | Format-Table Name,InitialSize,MaximumSize"
echo Pagefile configurado: 24576 MB inicial / 40960 MB maximo em C:\pagefile.sys (SSD).
echo Reinicie o Windows se o novo limite maximo ainda nao aparecer no Gerenciador de Tarefas.
pause
