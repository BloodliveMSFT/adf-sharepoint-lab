# ADF Lab: Download SharePoint Files using MS Graph API

This repository provides a production-ready, end-to-end lab for downloading files from a SharePoint Online document library to Azure Data Lake Storage (ADLS) Gen2 using Azure Data Factory (ADF) and the Microsoft Graph API. It uses a robust, managed-identity-based authentication pattern and includes fallback logic to refresh expired download URLs.

This solution is designed to be forkable and easily deployable for learning and experimentation. It includes both a one-click "Deploy to Azure" button and CLI-based deployment scripts.

## Architecture

For a detailed explanation of the components and data flow, please see the [Architecture Guide](./docs/architecture.md).

## Prerequisites

Before you begin, ensure you have the following:

1.  **Azure Subscription**: You need an active Azure subscription. [Create a free account here](https://azure.microsoft.com/free/).
2.  **Permissions**: You need permissions to:
    *   Create and manage resource groups and deployment in your Azure subscription.
    *   Create an **Entra ID (formerly Azure AD) Application Registration** in your tenant.
    *   Grant **Admin Consent** for Microsoft Graph API permissions.
3.  **Tools**:
    *   [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (for CLI deployment).
    *   [Git](https://git-scm.com/downloads/) (for cloning the repository).
    *   (Optional) [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell) (for `deploy.ps1`).

You can validate your local tools by running the prerequisite check script:
```bash
./scripts/validate-prereqs.sh
```

## Deployment

You have two options for deploying the necessary Azure resources.

### Option A: Deploy to Azure Button

This is the simplest method. Click the button below to deploy the Azure Data Factory with a system-assigned managed identity and the required RBAC role assignment on your storage account.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR_GITHUB_ORG_OR_USER%2FYOUR_REPO%2Fmain%2Fazuredeploy.json)

> **Note**: You must fork this repository and update the link above to point to the `azuredeploy.json` file in your own repository's `main` branch.

### Option B: CLI Deployment

Use the provided scripts to deploy the infrastructure using your local command line.

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/YOUR_GITHUB_ORG_OR_USER/YOUR_REPO.git
    cd YOUR_REPO
    ```

2.  **Run the deployment script**:

    You can set environment variables to customize the deployment, or use the defaults.

    **Bash:**
    ```bash
    # Example: Deploy to a specific storage account for RBAC
    export RG_NAME="my-adf-lab-rg"
    export LOCATION="westeurope"
    export STORAGE_ACCOUNT_ID="/subscriptions/YOUR_SUB_ID/resourceGroups/my-storage-rg/providers/Microsoft.Storage/storageAccounts/mystorageaccount"

    ./scripts/deploy.sh
    ```

    **PowerShell:**
    ```powershell
    # Example: Deploy to a specific storage account for RBAC
    $env:RG_NAME = "my-adf-lab-rg"
    $env:LOCATION = "westeurope"
    $env:STORAGE_ACCOUNT_ID = "/subscriptions/YOUR_SUB_ID/resourceGroups/my-storage-rg/providers/Microsoft.Storage/storageAccounts/mystorageaccount"

    ./scripts/deploy.ps1
    ```

## Post-Deployment Configuration

After the Azure resources are deployed, follow these steps to configure and run the pipeline.

1.  **Complete the Lab Guide**: Follow the step-by-step [**Lab Guide (docs/lab.md)**](./docs/lab.md) to create your Entra ID application, gather SharePoint details, and configure the pipeline.

2.  **Connect ADF to Your Git Repository (Manual Step)**:
    *   Open the newly created Data Factory in the Azure Portal and launch ADF Studio.
    *   Navigate to the **Manage** hub.
    *   Go to **Git configuration** and click **Configure**.
    *   Fill in your forked repository details:
        *   **Repository type**: GitHub
        *   **GitHub repository owner**: `YOUR_GITHUB_ORG_OR_USER`
        *   **Repository name**: `YOUR_REPO`
        *   **Collaboration branch**: `main`
        *   **Root folder**: `/adf`
        *   **Publish branch**: `adf_publish`
    *   Click **Apply**. ADF will now load the pipeline, datasets, and linked services from your repository.

3.  **Publish All Changes**:
    *   In the **Author** hub, click **Publish All** to save the resources from your Git repository into the live ADF service.

## Running the Pipeline

1.  In the **Author** hub, select the `pl_spo_to_adls_downloadUrl` pipeline.
2.  Click **Debug**.
3.  A panel will appear asking for pipeline parameters. Fill these in according to the values you gathered in the lab guide.

### Pipeline Parameters

| Parameter | Description | Example Value |
|---|---|---|
| `pTenantId` | Your Entra ID (Azure AD) tenant ID. | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `pClientId` | The Application (client) ID of your Entra app registration. | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `pClientSecret` | The client secret for your Entra app. **(Use a Key Vault reference in production!)** | `Your-App-Secret` |
| `pScope` | The permission scope for the Graph API token. | `https://graph.microsoft.com/.default` |
| `pSiteId` | The unique ID of the SharePoint site (host,site,web). | `contoso.sharepoint.com,xxxxxxxx-xxxx,...` |
| `pSiteName` | The user-friendly name of the SharePoint site (for the output path). | `MyTeamSite` |
| `pLibraryName` | The user-friendly name of the Document Library (for the output path). | `Documents` |
| `pDriveId` | The unique ID of the SharePoint Document Library (drive). | `b!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `pFolderPath` | The relative path to the folder within the library. | `/My Folder/Sub Folder` |
| `pSharePointHost` | The hostname of your SharePoint tenant. | `contoso.sharepoint.com` |
| `pStorageAccountName` | The name of your ADLS Gen2 storage account. | `youradlsaccount` |
| `pContainer` | The destination container in ADLS. | `landing` |
| `pRunDate` | The processing date, used in the output path. | `@formatDateTime(utcNow(),'yyyy-MM-dd')` |

### ADLS Output Location

Files will be downloaded to your ADLS Gen2 storage account with the following path structure:

```
landing/spo/site=<pSiteName>/library=<pLibraryName>/driveId=<pDriveId>/dt=<pRunDate>/<FileName>
```

**Example:**
`landing/spo/site=MyTeamSite/library=Documents/driveId=b!abc.../dt=2024-10-27/MyReport.xlsx`

## Security Notes

*   **Managed Identity**: The pipeline uses the Data Factory's System-Assigned Managed Identity (SAMI) to authenticate to the ADLS Gen2 storage account. No storage keys are required.
*   **RBAC**: The deployment templates automatically assign the `Storage Blob Data Contributor` role to the ADF's managed identity on the target storage account.
*   **Client Secret**: For simplicity, this lab passes the client secret as a `secureString` parameter. **In a production environment, you must store the secret in Azure Key Vault** and configure the `ls_rest_graph_oauth` linked service to retrieve it from there.

## Troubleshooting

If you encounter issues, please refer to the [**Troubleshooting Guide (docs/troubleshooting.md)**](./docs/troubleshooting.md) for common problems and solutions.
