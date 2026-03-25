@echo off
setlocal enabledelayedexpansion

:: Check if parameter is provided (Visual Studio build event)
if "%1"=="" (
    :: Manual mode: use default paths
    set RTC_SDK_DIR=%~dp0rtcLib\x86_64
    set RTM_SDK_DIR=%~dp0rtmLib\x86_64
    set BUILD_BIN_DIR=%~dp0build\bin
    set OUTPUT_DIR=%~dp0build\bin
    echo Manual mode: Copying DLLs to %OUTPUT_DIR%
) else (
    :: Visual Studio build event mode: use provided target directory
    set RTC_SDK_DIR=%~dp0rtcLib\x86_64
    set RTM_SDK_DIR=%~dp0rtmLib\x86_64
    set BUILD_BIN_DIR=%~dp0build\bin
    set OUTPUT_DIR=%1
    echo Build event mode: Copying DLLs to %OUTPUT_DIR%
)

:: Create output directory if it doesn't exist
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
    echo Created output directory: %OUTPUT_DIR%
)

echo ========================================
echo Copying Agora RTC SDK DLLs...
echo ========================================

:: Copy main Agora RTC SDK DLL (try build/bin first, then SDK dir)
if exist "%BUILD_BIN_DIR%\agora_rtc_sdk.dll" (
    copy "%BUILD_BIN_DIR%\agora_rtc_sdk.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: agora_rtc_sdk.dll (from build/bin)
    ) else (
        echo [ERROR] Failed to copy: agora_rtc_sdk.dll
    )
) else if exist "%RTC_SDK_DIR%\agora_rtc_sdk.dll" (
    copy "%RTC_SDK_DIR%\agora_rtc_sdk.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: agora_rtc_sdk.dll
    ) else (
        echo [ERROR] Failed to copy: agora_rtc_sdk.dll
    )
) else (
    echo [ERROR] agora_rtc_sdk.dll not found in %RTC_SDK_DIR% or %BUILD_BIN_DIR%
)

:: Copy video codec DLLs
if exist "%RTC_SDK_DIR%\video_enc.dll" (
    copy "%RTC_SDK_DIR%\video_enc.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: video_enc.dll
    ) else (
        echo [ERROR] Failed to copy: video_enc.dll
    )
)

if exist "%RTC_SDK_DIR%\video_dec.dll" (
    copy "%RTC_SDK_DIR%\video_dec.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: video_dec.dll
    ) else (
        echo [ERROR] Failed to copy: video_dec.dll
    )
)

:: Copy audio processing DLLs
if exist "%RTC_SDK_DIR%\libagora-fdkaac.dll" (
    copy "%RTC_SDK_DIR%\libagora-fdkaac.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libagora-fdkaac.dll
    ) else (
        echo [ERROR] Failed to copy: libagora-fdkaac.dll
    )
)

if exist "%RTC_SDK_DIR%\libagora-soundtouch.dll" (
    copy "%RTC_SDK_DIR%\libagora-soundtouch.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libagora-soundtouch.dll
    ) else (
        echo [ERROR] Failed to copy: libagora-soundtouch.dll
    )
)

if exist "%RTC_SDK_DIR%\libagora-ffmpeg.dll" (
    copy "%RTC_SDK_DIR%\libagora-ffmpeg.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libagora-ffmpeg.dll
    ) else (
        echo [ERROR] Failed to copy: libagora-ffmpeg.dll
    )
)

:: Copy other necessary DLLs
if exist "%RTC_SDK_DIR%\libaosl.dll" (
    copy "%RTC_SDK_DIR%\libaosl.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libaosl.dll
    ) else (
        echo [ERROR] Failed to copy: libaosl.dll
    )
)

if exist "%RTC_SDK_DIR%\glfw3.dll" (
    copy "%RTC_SDK_DIR%\glfw3.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: glfw3.dll
    ) else (
        echo [ERROR] Failed to copy: glfw3.dll
    )
)

:: Copy AI extension DLLs (as needed)
if exist "%RTC_SDK_DIR%\libagora_ai_echo_cancellation_extension.dll" (
    copy "%RTC_SDK_DIR%\libagora_ai_echo_cancellation_extension.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libagora_ai_echo_cancellation_extension.dll
    ) else (
        echo [ERROR] Failed to copy: libagora_ai_echo_cancellation_extension.dll
    )
)

if exist "%RTC_SDK_DIR%\libagora_ai_noise_suppression_extension.dll" (
    copy "%RTC_SDK_DIR%\libagora_ai_noise_suppression_extension.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: libagora_ai_noise_suppression_extension.dll
    ) else (
        echo [ERROR] Failed to copy: libagora_ai_noise_suppression_extension.dll
    )
)

echo.
echo Copying MFC runtime DLLs for portable deployment...

:: Try to locate Visual Studio Redist directory
set "VS_REDIST_DIR="
for %%V in (2022 2019 2017) do (
    for %%E in (Community Professional Enterprise) do (
        for /d %%D in ("C:\Program Files\Microsoft Visual Studio\%%V\%%E\VC\Redist\MSVC\14.*") do (
            if exist "%%D\x64\Microsoft.VC142.MFC\" (
                set "VS_REDIST_DIR=%%D\x64\Microsoft.VC142.MFC"
                goto :found_redist
            )
            if exist "%%D\x64\Microsoft.VC143.MFC\" (
                set "VS_REDIST_DIR=%%D\x64\Microsoft.VC143.MFC"
                goto :found_redist
            )
        )
    )
)

:found_redist
if defined VS_REDIST_DIR (
    echo Found MFC Redist: !VS_REDIST_DIR!
    
    :: Copy MFC DLLs
    if exist "!VS_REDIST_DIR!\mfc140u.dll" (
        copy "!VS_REDIST_DIR!\mfc140u.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (
            echo [OK] Copied: mfc140u.dll
        ) else (
            echo [ERROR] Failed to copy: mfc140u.dll
        )
    )
    
    if exist "!VS_REDIST_DIR!\mfcm140u.dll" (
        copy "!VS_REDIST_DIR!\mfcm140u.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (
            echo [OK] Copied: mfcm140u.dll
        ) else (
            echo [ERROR] Failed to copy: mfcm140u.dll
        )
    )
) else (
    echo [WARNING] Visual Studio Redist directory not found!
    echo Please manually copy these DLLs from:
    echo   C:\Program Files\Microsoft Visual Studio\[version]\[edition]\VC\Redist\MSVC\[version]\x64\Microsoft.VC14x.MFC\
    echo Required DLLs: mfc140u.dll, mfcm140u.dll
)

:: Copy VC++ Runtime DLLs (usually in System32, but try Redist too)
for %%V in (2022 2019 2017) do (
    for %%E in (Community Professional Enterprise) do (
        for /d %%D in ("C:\Program Files\Microsoft Visual Studio\%%V\%%E\VC\Redist\MSVC\14.*") do (
            if exist "%%D\x64\Microsoft.VC142.CRT\vcruntime140.dll" (
                copy "%%D\x64\Microsoft.VC142.CRT\vcruntime140.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
                if !errorlevel! equ 0 (echo [OK] Copied: vcruntime140.dll)
            )
            if exist "%%D\x64\Microsoft.VC142.CRT\vcruntime140_1.dll" (
                copy "%%D\x64\Microsoft.VC142.CRT\vcruntime140_1.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
                if !errorlevel! equ 0 (echo [OK] Copied: vcruntime140_1.dll)
            )
            if exist "%%D\x64\Microsoft.VC143.CRT\vcruntime140.dll" (
                copy "%%D\x64\Microsoft.VC143.CRT\vcruntime140.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
                if !errorlevel! equ 0 (echo [OK] Copied: vcruntime140.dll)
            )
            if exist "%%D\x64\Microsoft.VC143.CRT\vcruntime140_1.dll" (
                copy "%%D\x64\Microsoft.VC143.CRT\vcruntime140_1.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
                if !errorlevel! equ 0 (echo [OK] Copied: vcruntime140_1.dll)
            )
        )
    )
)

echo.
echo ========================================
echo Copying Agora RTM SDK DLLs...
echo ========================================

:: Copy Agora RTM SDK DLL
if exist "%RTM_SDK_DIR%\agora_rtm_sdk.dll" (
    copy "%RTM_SDK_DIR%\agora_rtm_sdk.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Copied: agora_rtm_sdk.dll
    ) else (
        echo [ERROR] Failed to copy: agora_rtm_sdk.dll
    )
) else (
    echo [WARNING] agora_rtm_sdk.dll not found in %RTM_SDK_DIR%
)

:: Note: libaosl.dll is already copied from RTC SDK directory above
:: Do NOT copy from RTM SDK directory as it may be a different version
:: and would overwrite the RTC SDK version, causing compatibility issues

echo.
echo ========================================
echo Copying vcpkg dependencies (libcurl)...
echo ========================================

:: Determine if Debug or Release build
set VCPKG_BIN_DIR=%~dp0vcpkg_installed\x64-windows\bin
set VCPKG_DEBUG_BIN_DIR=%~dp0vcpkg_installed\x64-windows\debug\bin

:: Check if output directory contains "Debug" to determine build type
echo %OUTPUT_DIR% | findstr /i "Debug" >nul
if %errorlevel% equ 0 (
    set BUILD_TYPE=Debug
    set VCPKG_BIN_SOURCE=%VCPKG_DEBUG_BIN_DIR%
) else (
    set BUILD_TYPE=Release
    set VCPKG_BIN_SOURCE=%VCPKG_BIN_DIR%
)

echo Build type detected: %BUILD_TYPE%
echo Source directory: %VCPKG_BIN_SOURCE%

:: Copy libcurl DLL
if "%BUILD_TYPE%"=="Debug" (
    if exist "%VCPKG_BIN_SOURCE%\libcurl-d.dll" (
        copy "%VCPKG_BIN_SOURCE%\libcurl-d.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (echo [OK] Copied: libcurl-d.dll) else (echo [ERROR] Failed to copy: libcurl-d.dll)
    )
) else (
    if exist "%VCPKG_BIN_SOURCE%\libcurl.dll" (
        copy "%VCPKG_BIN_SOURCE%\libcurl.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (echo [OK] Copied: libcurl.dll) else (echo [ERROR] Failed to copy: libcurl.dll)
    )
)

:: Copy zlib DLL
if "%BUILD_TYPE%"=="Debug" (
    if exist "%VCPKG_BIN_SOURCE%\zlibd1.dll" (
        copy "%VCPKG_BIN_SOURCE%\zlibd1.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (echo [OK] Copied: zlibd1.dll) else (echo [ERROR] Failed to copy: zlibd1.dll)
    )
) else (
    if exist "%VCPKG_BIN_SOURCE%\zlib1.dll" (
        copy "%VCPKG_BIN_SOURCE%\zlib1.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
        if !errorlevel! equ 0 (echo [OK] Copied: zlib1.dll) else (echo [ERROR] Failed to copy: zlib1.dll)
    )
)

:: Copy OpenSSL DLLs (if present)
if exist "%VCPKG_BIN_SOURCE%\libcrypto-3.dll" (
    copy "%VCPKG_BIN_SOURCE%\libcrypto-3.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (echo [OK] Copied: libcrypto-3.dll) else (echo [ERROR] Failed to copy: libcrypto-3.dll)
)
if exist "%VCPKG_BIN_SOURCE%\libssl-3.dll" (
    copy "%VCPKG_BIN_SOURCE%\libssl-3.dll" "%OUTPUT_DIR%\" /Y >nul 2>&1
    if !errorlevel! equ 0 (echo [OK] Copied: libssl-3.dll) else (echo [ERROR] Failed to copy: libssl-3.dll)
)

echo.
echo DLL copy completed!
echo Output directory: %OUTPUT_DIR%

:: If manual mode, pause for user confirmation
if "%1"=="" (
    pause
)