#!/usr/bin/env pwsh
# ============================================================================
# Validate Prerequisites for ADF Lab Deployment (PowerShell)
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ADF Lab Prerequisites Validation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$Errors = 0

# Check Azure CLI
Write-Host -NoNewline "Checking Azure CLI (az)... "
if (Get-Command az -ErrorAction SilentlyContinue) {
    try {
        $azVersion = (az version 2>$null | ConvertFrom-Json).'azure-cli'
        Write-Host "✓ Found (version: $azVersion)" -ForegroundColor Green
    } catch {
        Write-Host "✓ Found (version: unknown)" -ForegroundColor Green
    }
} else {
    Write-Host "✗ NOT FOUND" -ForegroundColor Red
    Write-Host "  Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    $Errors++
}

# Check Azure CLI login
Write-Host -NoNewline "Checking Azure CLI login... "
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "✓ Logged in (subscription: $($account.name))" -ForegroundColor Green
} catch {
    Write-Host "✗ NOT LOGGED IN" -ForegroundColor Red
    Write-Host "  Run: az login" -ForegroundColor Yellow
    $Errors++
}

# Check Git
Write-Host -NoNewline "Checking Git... "
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVersion = (git --version).Split(" ")[2]
    Write-Host "✓ Found (version: $gitVersion)" -ForegroundColor Green
} else {
    Write-Host "✗ NOT FOUND" -ForegroundColor Red
    Write-Host "  Install from: https://git-scm.com/downloads" -ForegroundColor Yellow
    $Errors++
}

# Check GitHub CLI (optional)
Write-Host -NoNewline "Checking GitHub CLI (gh) [optional]... "
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghVersion = (gh --version | Select-Object -First 1).Split(" ")[2]
    Write-Host "✓ Found (version: $ghVersion)" -ForegroundColor Green
} else {
    Write-Host "⚠ NOT FOUND (optional)" -ForegroundColor Yellow
    Write-Host "  Install from: https://cli.github.com/" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
if ($Errors -eq 0) {
    Write-Host "✓ All required prerequisites are met!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "✗ $Errors prerequisite(s) missing or not configured." -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Cyan
    exit 1
}
