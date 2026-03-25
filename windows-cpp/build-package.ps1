# VoiceAgent Build & Package Script
#
# Usage:
#   .\build-package.ps1                           # Build and create portable package
#   .\build-package.ps1 -Version "1.0.2"         # Specify version number
#   .\build-package.ps1 -Configuration Debug     # Debug build
#
# Note:
#   - Old build outputs are automatically cleaned before building
#   - This prevents DLL version mismatch issues
#
# Output:
#   packages/[timestamp]-v1.0.0-Release/
#       ├── Portable/VoiceAgent.exe + DLLs
#       └── VoiceAgent-[timestamp]-v1.0.0-Release.zip

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("x64")]
    [string]$Platform = "x64",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\packages",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

# Console color output function
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking build environment..." "Yellow"
    
    # Check MSBuild
    $msbuildPath = $null
    $vsInstallations = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    )
    
    foreach ($path in $vsInstallations) {
        if (Test-Path $path) {
            $msbuildPath = $path
            break
        }
    }
    
    if (-not $msbuildPath) {
        Write-ColorOutput "Error: MSBuild not found. Please ensure Visual Studio 2022 is installed." "Red"
        exit 1
    }
    Write-ColorOutput "Found MSBuild: $msbuildPath" "Green"

    # Check solution file
    if (-not (Test-Path "VoiceAgent.sln")) {
        Write-ColorOutput "Error: VoiceAgent.sln not found in current directory." "Red"
        Write-ColorOutput "Please run this script from the project root directory." "Yellow"
        exit 1
    }
    Write-ColorOutput "Found solution file: VoiceAgent.sln" "Green"

    return $msbuildPath
}

# Clear output directory
function Clear-OutputDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-ColorOutput "Clearing output directory: $Path" "Yellow"
        Remove-Item $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

# Build project
function Build-Project {
    param([string]$MsbuildPath, [string]$Configuration, [string]$Platform)
    
    Write-ColorOutput "Starting project build..." "Yellow"
    Write-ColorOutput "Configuration: $Configuration, Platform: $Platform" "Cyan"
    
    $buildArgs = @(
        "VoiceAgent.sln",
        "/p:Configuration=$Configuration",
        "/p:Platform=$Platform",
        "/verbosity:minimal"
    )
    
    $process = Start-Process -FilePath $MsbuildPath -ArgumentList $buildArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-ColorOutput "Build failed! Exit code: $($process.ExitCode)" "Red"
        exit 1
    }
    
    Write-ColorOutput "Build successful!" "Green"
}

# Copy dependencies
function Copy-Dependencies {
    param([string]$SourceDir, [string]$TargetDir)
    
    Write-ColorOutput "Copying dependencies..." "Yellow"
    
    # Create directory structure
    $dirs = @("")
    foreach ($dir in $dirs) {
        $targetPath = Join-Path $TargetDir $dir
        if (-not (Test-Path $targetPath)) {
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        }
    }
    
    # Copy main executable from build output
    $exePath = Join-Path $SourceDir "VoiceAgent.exe"
    if (Test-Path $exePath) {
        Copy-Item $exePath $TargetDir
        Write-ColorOutput "Copied main executable: VoiceAgent.exe" "Green"
    } else {
        Write-ColorOutput "Error: Main executable not found at: $exePath" "Red"
        Write-ColorOutput "Please ensure the project has been built successfully." "Yellow"
        return
    }
    
    # Copy all DLL files from build output directory
    # This ensures we get the exact DLLs that were used during compilation and testing in IDE
    Write-ColorOutput "Copying all DLLs from build output directory..." "Cyan"
    $dllFiles = Get-ChildItem -Path $SourceDir -Filter "*.dll" -ErrorAction SilentlyContinue
    foreach ($dll in $dllFiles) {
        Copy-Item $dll.FullName $TargetDir -Force
        Write-ColorOutput "Copied DLL: $($dll.Name)" "Green"
    }
}

# Create portable package
function Create-PortablePackage {
    param([string]$SourceDir, [string]$OutputPath, [string]$Version, [string]$Configuration, [string]$Timestamp)
    
    Write-ColorOutput "Creating portable package..." "Yellow"
    
    # Create portable subdirectory
    $portableDir = Join-Path $OutputPath "Portable"
    Clear-OutputDirectory $portableDir
    
    # Copy files
    Copy-Dependencies $SourceDir $portableDir

    # Keep the original VoiceAgent.exe name (no renaming needed)
    $exePath = Join-Path $portableDir "VoiceAgent.exe"
    if (Test-Path $exePath) {
        Write-ColorOutput "Main executable ready: VoiceAgent.exe" "Green"
    } else {
        Write-ColorOutput "Warning: Main executable not found in portable directory" "Yellow"
    }
    
    # Create startup script via lines join to avoid here-string issues
    $startupScriptLines = @(
        '@echo off',
        'chcp 65001 >nul',
        'title VoiceAgent Launcher',
        '',
        'echo ========================================',
        ("echo            VoiceAgent v$Version"),
        'echo ========================================',
        'echo.',
        '',
        'REM Check if main executable exists',
        'if not exist "VoiceAgent.exe" (',
        '    echo [ERROR] Main executable VoiceAgent.exe not found',
        '    pause',
        '    exit /b 1',
        ')',
        '',
        'echo [INFO] Starting VoiceAgent...',
        'start "" "VoiceAgent.exe"',
        'echo [INFO] Application started',
        'pause'
    )
    $startupScript = ($startupScriptLines -join "`r`n")
    $startupScript | Out-File (Join-Path $portableDir "StartVoiceAgent.bat") -Encoding ASCII
    
    # Create README file (ASCII only to avoid parser/codepage issues)
    $readmeContent = "# VoiceAgent Portable v$Version`r`n`r`n" +
        "AI Voice Conversation Application powered by Agora SDK`r`n`r`n" +
        "How to use:`r`n" +
        "1) Double-click StartVoiceAgent.bat`r`n" +
        "2) The application will launch`r`n`r`n" +
        "Files:`r`n" +
        "- VoiceAgent.exe (main executable)`r`n" +
        "- StartVoiceAgent.bat (launcher)`r`n" +
        "- agora_rtc_sdk.dll and other required DLLs`r`n`r`n" +
        "Notes:`r`n" +
        "- All Agora SDK DLLs are included in this package`r`n" +
        "- This is a portable version, no installation required`r`n" +
        "- For full source code, visit the project repository`r`n"
    
    $readmeContent | Out-File (Join-Path $portableDir "README.txt") -Encoding ASCII
    
    # Create ZIP package (with timestamp in filename)
    $zipPath = Join-Path $OutputPath "VoiceAgent-$Timestamp-v$Version-$Configuration.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    Write-ColorOutput "Creating ZIP package..." "Yellow"
    Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -CompressionLevel Fastest
    
    Write-ColorOutput "Portable package created successfully!" "Green"
    Write-ColorOutput "Directory: $portableDir" "Cyan"
    Write-ColorOutput "ZIP package: $zipPath" "Cyan"
}

# Create installer package
## removed installer packaging entirely

# Main function
function Main {
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput "      VoiceAgent Build & Package Tool" "Cyan"
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput ""
    
    # Check parameters
    Write-ColorOutput "Package parameters:" "Yellow"
    Write-ColorOutput "  Configuration: $Configuration" "White"
    Write-ColorOutput "  Platform: $Platform" "White"
    Write-ColorOutput "  Output path: $OutputPath" "White"
    Write-ColorOutput "  Version: $Version" "White"
    Write-ColorOutput ""
    
    # Check prerequisites
    $msbuildPath = Test-Prerequisites
    
    # Clear output directory
    if ($Clean) {
        Clear-OutputDirectory $OutputPath
    }
    
    # Build project
    if (-not $SkipBuild) {
        # Always clean old output directories before building (prevents cache issues)
        Write-ColorOutput "Cleaning old build outputs (required before packaging)..." "Yellow"
        $cleanPaths = @(
            "x64\$Configuration",
            "VoiceAgent\project\x64\$Configuration",
            "VoiceAgent\x64\$Configuration"
        )
        foreach ($cleanPath in $cleanPaths) {
            if (Test-Path $cleanPath) {
                Remove-Item $cleanPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "  Cleaned: $cleanPath" "Green"
            }
        }
        
        Build-Project $msbuildPath $Configuration $Platform
    }
    
    # Determine source directory - support multiple possible paths
    # Priority: IDE project output first, then fallback to other locations
    $possiblePaths = @(
        "VoiceAgent\project\x64\$Configuration",  # Visual Studio IDE output (highest priority)
        "x64\$Configuration",                     # Root level build output
        "VoiceAgent\x64\$Configuration",
        "VoiceAgent\build\x64\$Configuration"
    )
    
    $sourceDir = $null
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            # Check if the directory contains the main executable
            $testExePath = Join-Path $path "VoiceAgent.exe"
            if (Test-Path $testExePath) {
                $sourceDir = $path
                Write-ColorOutput "Found build output directory: $sourceDir" "Green"
                break
            }
        }
    }
    
    if (-not $sourceDir) {
        Write-ColorOutput "Error: Build output directory not found" "Red"
        Write-ColorOutput "Tried paths:" "Red"
        foreach ($path in $possiblePaths) {
            Write-ColorOutput "  $path" "Red"
        }
        Write-ColorOutput "Please ensure the project has been built successfully." "Yellow"
        exit 1
    }
    
    # Create timestamped output directory
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $timestampedOutputPath = Join-Path $OutputPath "$timestamp-v$Version-$Configuration"
    if (-not (Test-Path $timestampedOutputPath)) {
        New-Item -ItemType Directory -Path $timestampedOutputPath -Force | Out-Null
    }
    Write-ColorOutput "Created timestamped output directory: $timestampedOutputPath" "Green"
    
    # Create portable package only
    Create-PortablePackage $sourceDir $timestampedOutputPath $Version $Configuration $timestamp
    
    Write-ColorOutput ""
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput "      Package creation completed!" "Green"
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput "Output directory: $OutputPath" "White"
}

# Execute main function
try {
    Main
} catch {
    Write-ColorOutput "Error occurred during packaging: $($_.Exception.Message)" "Red"
    exit 1
}
