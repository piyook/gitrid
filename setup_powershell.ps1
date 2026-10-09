#!/usr/bin/env pwsh

# gitrid PowerShell Setup Script
# This script installs gitrid for PowerShell on Windows

Write-Host "gitrid PowerShell Setup" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

# Check if WSL is available
Write-Host "Checking WSL availability..." -ForegroundColor Yellow
try {
    $wslCheck = wsl --list --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ WSL is available" -ForegroundColor Green
    } else {
        Write-Host "✗ WSL is not available or not properly configured" -ForegroundColor Red
        Write-Host "Please install WSL before using gitrid on Windows" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ WSL is not available or not properly configured" -ForegroundColor Red
    Write-Host "Please install WSL before using gitrid on Windows" -ForegroundColor Red
    exit 1
}

# Define paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceBat = Join-Path $ScriptDir "gitrid.bat"
$DestinationBat = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\gitrid.bat"
# PowerShell runs gitrid.ps1 in preference to gitrid.bat, which is left for cmd.
# A batch file loses the ^ of a pattern such as ^fix/ when PowerShell runs it.
$SourcePs1 = Join-Path $ScriptDir "gitrid.ps1"
$DestinationPs1 = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\gitrid.ps1"

# Check if the source files exist
foreach ($Source in $SourceBat, $SourcePs1) {
    if (-not (Test-Path $Source)) {
        Write-Host "✗ $(Split-Path -Leaf $Source) not found in current directory" -ForegroundColor Red
        Write-Host "Please run this script from the gitrid directory" -ForegroundColor Red
        exit 1
    }
}

# Check if gitrid is already installed
if (Test-Path $DestinationBat) {
    Write-Host "gitrid is already installed. Updating..." -ForegroundColor Yellow
    
    # Check current version
    try {
        $currentVersion = & gitrid --version 2>$null
        Write-Host "Current version: $currentVersion" -ForegroundColor Cyan
    } catch {
        Write-Host "Could not determine current version" -ForegroundColor Yellow
    }
} else {
    Write-Host "Installing gitrid for PowerShell..." -ForegroundColor Yellow
}

# Copy the batch file and the PowerShell script to WindowsApps directory
try {
    Copy-Item $SourceBat $DestinationBat -Force
    Write-Host "✓ gitrid.bat copied to $DestinationBat" -ForegroundColor Green
    Copy-Item $SourcePs1 $DestinationPs1 -Force
    Write-Host "✓ gitrid.ps1 copied to $DestinationPs1" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to copy the gitrid files: $_" -ForegroundColor Red
    exit 1
}

# Verify WSL script exists and is up to date
Write-Host "Checking WSL installation..." -ForegroundColor Yellow
try {
    $wslScriptPath = "/usr/local/bin/gitrid.sh"
    $wslVersion = wsl sh -c "grep 'VERSION=' $wslScriptPath 2>/dev/null || echo 'NOT_FOUND'"
    
    if ($wslVersion -eq "NOT_FOUND") {
        Write-Host "WSL script not found. Please run setup_linux.sh in WSL first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ WSL script found: $wslVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Could not verify WSL installation: $_" -ForegroundColor Yellow
    Write-Host "Please ensure gitrid is properly installed in WSL" -ForegroundColor Yellow
}

# Test the installation
Write-Host "Testing gitrid installation..." -ForegroundColor Yellow
try {
    $testVersion = & gitrid --version
    Write-Host "✓ gitrid is working: $testVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ gitrid test failed: $_" -ForegroundColor Red
    Write-Host "Please check your WSL installation and PATH" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "You can now use 'gitrid' from PowerShell" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  gitrid --help          # Show help" -ForegroundColor White
Write-Host "  gitrid --version       # Show version" -ForegroundColor White
Write-Host "  gitrid feature/        # Delete branches matching pattern" -ForegroundColor White
Write-Host "  gitrid --merged feature/ # Delete merged branches matching pattern" -ForegroundColor White
Write-Host "  gitrid --list           # List all branches with status" -ForegroundColor White
