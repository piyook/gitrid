#!/usr/bin/env pwsh

# GitCrop PowerShell Setup Script
# This script installs GitCrop for PowerShell on Windows

Write-Host "GitCrop PowerShell Setup" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

# Check if WSL is available
Write-Host "Checking WSL availability..." -ForegroundColor Yellow
try {
    $wslCheck = wsl --list --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ WSL is available" -ForegroundColor Green
    } else {
        Write-Host "✗ WSL is not available or not properly configured" -ForegroundColor Red
        Write-Host "Please install WSL before using GitCrop on Windows" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ WSL is not available or not properly configured" -ForegroundColor Red
    Write-Host "Please install WSL before using GitCrop on Windows" -ForegroundColor Red
    exit 1
}

# Define paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceBat = Join-Path $ScriptDir "gitcrop.bat"
$DestinationBat = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\gitcrop.bat"

# Check if source batch file exists
if (-not (Test-Path $SourceBat)) {
    Write-Host "✗ gitcrop.bat not found in current directory" -ForegroundColor Red
    Write-Host "Please run this script from the GitCrop directory" -ForegroundColor Red
    exit 1
}

# Check if GitCrop is already installed
if (Test-Path $DestinationBat) {
    Write-Host "GitCrop is already installed. Updating..." -ForegroundColor Yellow
    
    # Check current version
    try {
        $currentVersion = & gitcrop --version 2>$null
        Write-Host "Current version: $currentVersion" -ForegroundColor Cyan
    } catch {
        Write-Host "Could not determine current version" -ForegroundColor Yellow
    }
} else {
    Write-Host "Installing GitCrop for PowerShell..." -ForegroundColor Yellow
}

# Copy the batch file to WindowsApps directory
try {
    Copy-Item $SourceBat $DestinationBat -Force
    Write-Host "✓ gitcrop.bat copied to $DestinationBat" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to copy gitcrop.bat: $_" -ForegroundColor Red
    exit 1
}

# Verify WSL script exists and is up to date
Write-Host "Checking WSL installation..." -ForegroundColor Yellow
try {
    $wslScriptPath = "/usr/local/bin/gitcrop.sh"
    $wslVersion = wsl sh -c "grep 'VERSION=' $wslScriptPath 2>/dev/null || echo 'NOT_FOUND'"
    
    if ($wslVersion -eq "NOT_FOUND") {
        Write-Host "WSL script not found. Please run setup_linux.sh in WSL first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ WSL script found: $wslVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Could not verify WSL installation: $_" -ForegroundColor Yellow
    Write-Host "Please ensure GitCrop is properly installed in WSL" -ForegroundColor Yellow
}

# Test the installation
Write-Host "Testing GitCrop installation..." -ForegroundColor Yellow
try {
    $testVersion = & gitcrop --version
    Write-Host "✓ GitCrop is working: $testVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ GitCrop test failed: $_" -ForegroundColor Red
    Write-Host "Please check your WSL installation and PATH" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "You can now use 'gitcrop' from PowerShell" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  gitcrop --help          # Show help" -ForegroundColor White
Write-Host "  gitcrop --version       # Show version" -ForegroundColor White
Write-Host "  gitcrop feature/        # Delete branches matching pattern" -ForegroundColor White
Write-Host "  gitcrop --merged feature/ # Delete merged branches matching pattern" -ForegroundColor White
Write-Host "  gitcrop --list           # List all branches with status" -ForegroundColor White
