# Script to check and copy KeyCenter.h from template
# Simple approach: just copy the template if KeyCenter.h doesn't exist
# The template itself contains #error directive for clear IDE error messages

$ErrorActionPreference = "Continue"

try {
    # Determine project paths
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $ProjectRoot = Split-Path -Parent $ScriptDir
    $KeyCenterFile = Join-Path $ProjectRoot "VoiceAgent\src\KeyCenter.h"
    $TemplateFile = Join-Path $ProjectRoot "KeyCenter.h.example"
    
    Write-Host "Checking KeyCenter.h configuration..." -ForegroundColor Cyan
    
    # Check if KeyCenter.h exists
    if (-not (Test-Path $KeyCenterFile)) {
        Write-Host "KeyCenter.h not found. Copying from template..." -ForegroundColor Yellow
        
        # Check if template exists
        if (-not (Test-Path $TemplateFile)) {
            Write-Host "ERROR: Template file not found: $TemplateFile" -ForegroundColor Red
            Write-Host "Please restore KeyCenter.h.example to project root" -ForegroundColor Yellow
            exit 1
        }
        
        # Ensure directory exists
        $KeyCenterDir = Split-Path -Parent $KeyCenterFile
        if (-not (Test-Path $KeyCenterDir)) {
            New-Item -ItemType Directory -Path $KeyCenterDir -Force | Out-Null
        }
        
        # Copy template to KeyCenter.h
        Copy-Item $TemplateFile $KeyCenterFile -Force
        Write-Host "Created KeyCenter.h from template" -ForegroundColor Green
        Write-Host "" 
        Write-Host "NEXT STEP: Configure your credentials in KeyCenter.h" -ForegroundColor Yellow
        Write-Host "The build will show detailed instructions in the Error List" -ForegroundColor Gray
        Write-Host ""
    }
    else {
        Write-Host "KeyCenter.h exists" -ForegroundColor Green
    }
    
    # Always exit 0 to let compilation continue and show #error if present
    exit 0
}
catch {
    Write-Host "Script error: $_" -ForegroundColor Red
    # Still exit 0 to allow build to show any existing errors
    exit 0
}
