#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Deploy Azure Data Factory + RBAC (Optional Git Integration)
# ============================================================================

echo "=========================================="
echo "ADF Lab Deployment Script"
echo "=========================================="

# Default values
RG_NAME="${RG_NAME:-adf-spo-lab-rg}"
LOCATION="${LOCATION:-eastus}"
FACTORY_NAME="${FACTORY_NAME:-adf-spo-to-adls-lab}"
STORAGE_ACCOUNT_ID="${STORAGE_ACCOUNT_ID:-}"

echo ""
echo "Configuration:"
echo "  Resource Group: $RG_NAME"
echo "  Location: $LOCATION"
echo "  Factory Name: $FACTORY_NAME"
echo "  Storage Account ID: ${STORAGE_ACCOUNT_ID:-<none - skip RBAC>}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
  echo "ERROR: Azure CLI (az) is not installed."
  echo "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

# Check if logged in
echo "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
  echo "ERROR: Not logged in to Azure CLI."
  echo "Run: az login"
  exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "Logged in to subscription: $SUBSCRIPTION_NAME"
echo ""

# Create resource group
echo "Creating resource group: $RG_NAME in $LOCATION..."
az group create --name "$RG_NAME" --location "$LOCATION" --output table
echo ""

# Deploy Bicep template (no Git integration)
echo "Deploying Azure Data Factory (no Git integration)..."
az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file infra/main_no_git.bicep \
  --parameters location="$LOCATION" factoryName="$FACTORY_NAME" storageAccountId="$STORAGE_ACCOUNT_ID" \
  --output table
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Open Azure Portal → Data Factory → $FACTORY_NAME → Launch ADF Studio"
echo "2. Connect to Git (optional):"
echo "   - Go to Manage → Git configuration → Configure"
echo "   - Select GitHub, provide repo URL, branch=main, root folder=/adf"
echo "3. Publish the pipeline:"
echo "   - In ADF Studio → Author → Publish All"
echo "4. Run the pipeline:"
echo "   - Debug → Supply pipeline parameters (see README.md for examples)"
echo ""
echo "For detailed instructions, see docs/lab.md"
echo ""
