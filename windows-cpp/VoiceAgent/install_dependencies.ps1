# Install Agora SDKs for VoiceAgent Project
# This script automatically downloads RTC and RTM SDKs

$ErrorActionPreference = "Stop"

# ========================================
# Configuration - SDK Download URLs
# ========================================
$RTC_SDK_URL = "https://download.shengwang.cn/sdk/release/Shengwang_Native_SDK_for_Windows_v4.6.0_FULL.zip"
$RTM_SDK_URL = "https://download.agora.io/rtm2/release/Agora_RTM_C%2B%2B_SDK_for_Windows_v2.2.6.zip"

# ========================================
# Helper Functions
# ========================================

# Function to download and extract SDK
function Install-AgoraSDK {
    param(
        [string]$SdkName,
        [string]$DownloadUrl,
        [string]$TargetDir
    )
    
    Write-Host "Downloading $SdkName..." -ForegroundColor Cyan
    Write-Host "  URL: $DownloadUrl" -ForegroundColor Gray
    
    # Use system temp directory to avoid long path issues under deep project roots
    $tempBasePath   = [System.IO.Path]::GetTempPath()
    $zipPath        = Join-Path $tempBasePath "$($SdkName)_temp.zip"
    $extractPath    = Join-Path $tempBasePath "$($SdkName)_temp"
    
    try {
        # Download
        Write-Host "  [1/3] Downloading..." -ForegroundColor Yellow
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        $fileSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  Downloaded $([math]::Round($fileSize, 2)) MB (saved to $zipPath)" -ForegroundColor Green
        
        # Extract (to temp to minimize path length; suppress non-fatal entry errors)
        Write-Host "  [2/3] Extracting to temp..." -ForegroundColor Yellow
        if (Test-Path $extractPath) {
            Remove-Item -Recurse -Force $extractPath
        }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction SilentlyContinue
        Write-Host "  Extracted (best-effort) to $extractPath" -ForegroundColor Green
        
        # Organize into target directory
        Write-Host "  [3/3] Organizing files..." -ForegroundColor Yellow
        
        # Find a folder that looks like the SDK root (contains high_level_api or x86_64)
        $candidateRoots = Get-ChildItem -Path $extractPath -Recurse -Directory |
            Where-Object {
                (Test-Path (Join-Path $_.FullName "high_level_api")) -or
                (Test-Path (Join-Path $_.FullName "x86_64"))
            } |
            Select-Object -First 1
        
        if (-not $candidateRoots) {
            throw "Could not locate SDK root (no folder with high_level_api/ or x86_64/ found under $extractPath)"
        }
        
        $sdkRoot = $candidateRoots.FullName
        Write-Host "  Detected SDK root: $sdkRoot" -ForegroundColor Gray
        
        # Clean target directory if exists
        if (Test-Path $TargetDir) {
            Remove-Item -Recurse -Force $TargetDir
        }
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        
        # Move high_level_api (headers)
        $highLevelSrc = Join-Path $sdkRoot "high_level_api"
        if (Test-Path $highLevelSrc) {
            $highLevelDst = Join-Path $TargetDir "high_level_api"
            Move-Item -Path $highLevelSrc -Destination $highLevelDst
            Write-Host "  Moved high_level_api -> $highLevelDst" -ForegroundColor Green
        }
        
        # Move x86_64 (libs + DLLs)
        $libSrc = Join-Path $sdkRoot "x86_64"
        if (Test-Path $libSrc) {
            $libDst = Join-Path $TargetDir "x86_64"
            Move-Item -Path $libSrc -Destination $libDst
            Write-Host "  Moved x86_64 -> $libDst" -ForegroundColor Green
        }
        
        # Cleanup
        Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $extractPath -ErrorAction SilentlyContinue
        
        Write-Host "  [✓] $SdkName setup complete!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  [✗] Failed to install $SdkName!" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Cleanup on failure
        Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $extractPath -ErrorAction SilentlyContinue
        
        return $false
    }
}

# ========================================
# Main Script
# ========================================
Write-Host ""
Write-Host "=== Installing Agora SDKs for VoiceAgent ===" -ForegroundColor Green
Write-Host ""

$rtcLibDir = Join-Path $PSScriptRoot "rtcLib"
$rtmLibDir = Join-Path $PSScriptRoot "rtmLib"

# Check if SDKs exist
$needDownloadRtc = $false
$needDownloadRtm = $false

# Check RTC SDK
Write-Host "Checking RTC SDK..." -ForegroundColor Cyan
$hasRtcDll = Test-Path (Join-Path $rtcLibDir "x86_64\agora_rtc_sdk.dll.lib")
if (!$hasRtcDll) {
    Write-Host "  RTC SDK not found in rtcLib/" -ForegroundColor Yellow
    $needDownloadRtc = $true
} else {
    Write-Host "  [✓] RTC SDK already installed" -ForegroundColor Green
}

# Check RTM SDK
Write-Host "Checking RTM SDK..." -ForegroundColor Cyan
$hasRtmDll = Test-Path (Join-Path $rtmLibDir "x86_64\agora_rtm_sdk.dll.lib")
if (!$hasRtmDll) {
    Write-Host "  RTM SDK not found in rtmLib/" -ForegroundColor Yellow
    $needDownloadRtm = $true
} else {
    Write-Host "  [✓] RTM SDK already installed" -ForegroundColor Green
}

# Download and install RTC SDK
if ($needDownloadRtc) {
    Write-Host ""
    Write-Host "--- Installing RTC SDK ---" -ForegroundColor Yellow
    
    $success = Install-AgoraSDK -SdkName "RTC_SDK" `
                                -DownloadUrl $RTC_SDK_URL `
                                -TargetDir $rtcLibDir
    
    if (!$success) {
        Write-Host ""
        Write-Host "Failed to install RTC SDK. Please download manually from:" -ForegroundColor Red
        Write-Host "  $RTC_SDK_URL" -ForegroundColor Yellow
        exit 1
    }
}

# Download and install RTM SDK
if ($needDownloadRtm) {
    Write-Host ""
    Write-Host "--- Installing RTM SDK ---" -ForegroundColor Yellow
    
    $success = Install-AgoraSDK -SdkName "RTM_SDK" `
                                -DownloadUrl $RTM_SDK_URL `
                                -TargetDir $rtmLibDir
    
    if (!$success) {
        Write-Host ""
        Write-Host "Warning: Failed to install RTM SDK" -ForegroundColor Yellow
        Write-Host "RTM features will not be available" -ForegroundColor Yellow
    }
}

# ========================================
# Install vcpkg dependencies (curl, nlohmann-json)
# ========================================

Write-Host ""
Write-Host "--- Installing vcpkg dependencies ---" -ForegroundColor Yellow

$vcpkgDir  = Join-Path $PSScriptRoot "vcpkg"
$vcpkgExe  = Join-Path $vcpkgDir "vcpkg.exe"

if (-not (Test-Path $vcpkgExe)) {
    Write-Host "vcpkg not found under $vcpkgDir. Cloning and bootstrapping..." -ForegroundColor Cyan
    try {
        git --version | Out-Null
    }
    catch {
        Write-Host "Error: git is required to clone vcpkg. Please install git and re-run this script." -ForegroundColor Red
        exit 1
    }

    git clone https://github.com/microsoft/vcpkg.git $vcpkgDir
    & "$vcpkgDir\bootstrap-vcpkg.bat"
}
else {
    Write-Host "vcpkg already exists. Skipping clone/bootstrap." -ForegroundColor Green
}

if (Test-Path $vcpkgExe) {
    Write-Host "Running vcpkg install (triplet: x64-windows) using vcpkg.json manifest..." -ForegroundColor Cyan
    & $vcpkgExe install --triplet x64-windows
} else {
    Write-Host "Error: vcpkg.exe not found after bootstrap. Please check vcpkg installation." -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "=== Dependency Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Installed components:" -ForegroundColor Yellow
Write-Host "  [OK] RTC SDK -> rtcLib/" -ForegroundColor Green
Write-Host "  [OK] RTM SDK -> rtmLib/" -ForegroundColor Green
Write-Host "  [OK] vcpkg dependencies (curl, nlohmann-json)" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Open project/VoiceAgent.vcxproj in Visual Studio" -ForegroundColor White
Write-Host "  2. Build the project (all dependencies are now installed)" -ForegroundColor White
Write-Host "  3. Run the application" -ForegroundColor White
Write-Host ""
