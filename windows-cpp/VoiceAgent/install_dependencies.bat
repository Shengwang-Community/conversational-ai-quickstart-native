@echo off
setlocal

REM Simple wrapper to install Agora RTC/RTM SDKs for VoiceAgent
REM Double-click this file to install all required Agora dependencies for the Windows demo.

echo.
echo ================================================
echo   Installing Agora SDKs for VoiceAgent
echo ================================================
echo.

REM Change working directory to the folder of this BAT (VoiceAgent)
cd /d "%~dp0"

REM Try to unblock the PowerShell script in case it was downloaded from the internet
powershell -Command "if (Test-Path '.\install_dependencies.ps1') { Unblock-File -Path '.\install_dependencies.ps1' -ErrorAction SilentlyContinue }"

REM Run the PowerShell install script
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
