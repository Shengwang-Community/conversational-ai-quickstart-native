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
    
    $zipPath = Join-Path $PSScriptRoot "$($SdkName)_temp.zip"
    $extractPath = Join-Path $PSScriptRoot "$($SdkName)_temp"
    
    try {
        # Download
        Write-Host "  [1/3] Downloading..." -ForegroundColor Yellow
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        $fileSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  Downloaded $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
        
        # Extract
        Write-Host "  [2/3] Extracting..." -ForegroundColor Yellow
        if (Test-Path $extractPath) {
            Remove-Item -Recurse -Force $extractPath
        }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Host "  Extracted successfully" -ForegroundColor Green
        
        # Move to target directory
        Write-Host "  [3/3] Organizing files..." -ForegroundColor Yellow
        $extractedFolders = Get-ChildItem -Path $extractPath -Directory
        
        if ($extractedFolders.Count -eq 1) {
            $sdkSourceDir = Join-Path $extractedFolders[0].FullName "sdk"
            if (Test-Path $sdkSourceDir) {
                # Clean target directory if exists
                if (Test-Path $TargetDir) {
                    Remove-Item -Recurse -Force $TargetDir
                }
                Move-Item -Path $sdkSourceDir -Destination $TargetDir
                Write-Host "  $SdkName installed to: $TargetDir" -ForegroundColor Green
            } else {
                # Alternative: extracted folder is the SDK
                if (Test-Path $TargetDir) {
                    Remove-Item -Recurse -Force $TargetDir
                }
                Move-Item -Path $extractedFolders[0].FullName -Destination $TargetDir
                Write-Host "  $SdkName installed to: $TargetDir" -ForegroundColor Green
            }
        } else {
            throw "Unexpected archive structure: found $($extractedFolders.Count) folders"
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

# Summary
Write-Host ""
Write-Host "=== SDK Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Installed SDKs:" -ForegroundColor Yellow
Write-Host "  [✓] RTC SDK → rtcLib/" -ForegroundColor Green
Write-Host "  [✓] RTM SDK → rtmLib/" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Open project/VoiceAgent.vcxproj in Visual Studio" -ForegroundColor White
Write-Host "  2. Build the project (vcpkg will auto-install dependencies)" -ForegroundColor White
Write-Host "  3. Run the application" -ForegroundColor White
Write-Host ""
