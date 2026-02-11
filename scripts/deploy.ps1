#!/usr/bin/env pwsh
# ============================================================================
# Deploy Azure Data Factory + RBAC (Optional Git Integration)
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ADF Lab Deployment Script (PowerShell)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Default values
$RG_NAME = if ($env:RG_NAME) { $env:RG_NAME } else { "adf-spo-lab-rg" }
$LOCATION = if ($env:LOCATION) { $env:LOCATION } else { "eastus" }
$FACTORY_NAME = if ($env:FACTORY_NAME) { $env:FACTORY_NAME } else { "adf-spo-to-adls-lab" }
$STORAGE_ACCOUNT_ID = if ($env:STORAGE_ACCOUNT_ID) { $env:STORAGE_ACCOUNT_ID } else { "" }

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $RG_NAME"
Write-Host "  Location: $LOCATION"
Write-Host "  Factory Name: $FACTORY_NAME"
Write-Host "  Storage Account ID: $(if ($STORAGE_ACCOUNT_ID) { $STORAGE_ACCOUNT_ID } else { '<none - skip RBAC>' })"
Write-Host ""

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Azure CLI (az) is not installed." -ForegroundColor Red
    Write-Host "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

# Check if logged in
Write-Host "Checking Azure CLI login status..."
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "Logged in to subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Not logged in to Azure CLI." -ForegroundColor Red
    Write-Host "Run: az login" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Create resource group
Write-Host "Creating resource group: $RG_NAME in $LOCATION..." -ForegroundColor Yellow
az group create --name $RG_NAME --location $LOCATION --output table
Write-Host ""

# Deploy Bicep template (no Git integration)
Write-Host "Deploying Azure Data Factory (no Git integration)..." -ForegroundColor Yellow
az deployment group create `
  --resource-group $RG_NAME `
  --template-file infra/main_no_git.bicep `
  --parameters location=$LOCATION factoryName=$FACTORY_NAME storageAccountId=$STORAGE_ACCOUNT_ID `
  --output table
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open Azure Portal → Data Factory → $FACTORY_NAME → Launch ADF Studio"
Write-Host "2. Connect to Git (optional):"
Write-Host "   - Go to Manage → Git configuration → Configure"
Write-Host "   - Select GitHub, provide repo URL, branch=main, root folder=/adf"
Write-Host "3. Publish the pipeline:"
Write-Host "   - In ADF Studio → Author → Publish All"
Write-Host "4. Run the pipeline:"
Write-Host "   - Debug → Supply pipeline parameters (see README.md for examples)"
Write-Host ""
Write-Host "For detailed instructions, see docs/lab.md" -ForegroundColor Cyan
Write-Host ""
