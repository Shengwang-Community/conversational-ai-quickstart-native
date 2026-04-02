@echo off
setlocal

REM Double-clickable entrypoint for installing all Windows demo dependencies.

cd /d "%~dp0"

powershell -Command "if (Test-Path '.\install_dependencies.ps1') { Unblock-File -Path '.\install_dependencies.ps1' -ErrorAction SilentlyContinue }"

powershell -ExecutionPolicy Bypass -File ".\install_dependencies.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to run install_dependencies.ps1
    echo Please make sure PowerShell is installed and the SDK download URLs are reachable.
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [OK] Agora SDK install script finished.
echo You can now open VoiceAgent.sln and build the project.
echo.
pause

endlocal
