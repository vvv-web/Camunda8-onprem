@echo off
setlocal
cd /d "%~dp0"

echo Starting Camunda one-click SAFE...
set "SCRIPT_PATH=%~dp0camunda-windows-oneclick-fullauto.ps1"
set "LOG_PATH=%~dp0camunda-run.log"

if not exist "%SCRIPT_PATH%" (
  echo.
  echo [ERROR] Main script not found:
  echo %SCRIPT_PATH%
  echo.
  echo Most likely you ran START_CAMUNDA.cmd directly from inside ZIP preview.
  echo Please do this:
  echo   1^) Right-click ZIP -^> Extract All...
  echo   2^) Open extracted folder
  echo   3^) Run START_CAMUNDA.cmd again
  echo.
  pause
  exit /b 2
)

echo Writing log to: %LOG_PATH%
echo ==== %DATE% %TIME% ==== > "%LOG_PATH%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" >> "%LOG_PATH%" 2>&1
set EXIT_CODE=%ERRORLEVEL%

echo.
echo ==============================
echo Script output:
echo ==============================
type "%LOG_PATH%"
echo ==============================
echo Exit code: %EXIT_CODE%
echo ==============================
echo.
echo Press any key to close this window...
pause >nul

endlocal
