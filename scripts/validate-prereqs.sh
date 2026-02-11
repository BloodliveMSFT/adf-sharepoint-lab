#!/usr/bin/env bash
# ============================================================================
# Validate Prerequisites for ADF Lab Deployment
# ============================================================================

set -euo pipefail

echo "=========================================="
echo "ADF Lab Prerequisites Validation"
echo "=========================================="
echo ""

ERRORS=0

# Check Azure CLI
echo -n "Checking Azure CLI (az)... "
if command -v az &> /dev/null; then
  AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
  echo "✓ Found (version: $AZ_VERSION)"
else
  echo "✗ NOT FOUND"
  echo "  Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  ERRORS=$((ERRORS + 1))
fi

# Check Azure CLI login
echo -n "Checking Azure CLI login... "
if az account show &> /dev/null; then
  SUBSCRIPTION=$(az account show --query name -o tsv)
  echo "✓ Logged in (subscription: $SUBSCRIPTION)"
else
  echo "✗ NOT LOGGED IN"
  echo "  Run: az login"
  ERRORS=$((ERRORS + 1))
fi

# Check Git
echo -n "Checking Git... "
if command -v git &> /dev/null; then
  GIT_VERSION=$(git --version | awk '{print $3}')
  echo "✓ Found (version: $GIT_VERSION)"
else
  echo "✗ NOT FOUND"
  echo "  Install from: https://git-scm.com/downloads"
  ERRORS=$((ERRORS + 1))
fi

# Check GitHub CLI (optional but recommended)
echo -n "Checking GitHub CLI (gh) [optional]... "
if command -v gh &> /dev/null; then
  GH_VERSION=$(gh --version | head -n1 | awk '{print $3}')
  echo "✓ Found (version: $GH_VERSION)"
else
  echo "⚠ NOT FOUND (optional)"
  echo "  Install from: https://cli.github.com/"
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
  echo "✓ All required prerequisites are met!"
  echo "=========================================="
  exit 0
else
  echo "✗ $ERRORS prerequisite(s) missing or not configured."
  echo "=========================================="
  exit 1
fi
