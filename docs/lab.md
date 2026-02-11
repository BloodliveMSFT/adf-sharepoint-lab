# Lab Guide: Downloading SharePoint Files with ADF

This guide provides a step-by-step walkthrough for configuring and running the ADF pipeline to download files from SharePoint Online.

## Step 1: Create an Entra ID Application Registration

The pipeline needs a service principal to authenticate with the Microsoft Graph API and get the list of files.

1.  Navigate to the **Azure Active Directory (Entra ID)** service in the Azure Portal.
2.  Go to **App registrations** and click **+ New registration**.
3.  Give it a descriptive name, such as `ADF-SharePoint-Graph-Access`.
4.  Leave the other options as default and click **Register**.
5.  Once created, copy the following values from the **Overview** page. You will need them later:
    *   **Application (client) ID** (this is `pClientId`)
    *   **Directory (tenant) ID** (this is `pTenantId`)

6.  Go to **Certificates & secrets**, click **+ New client secret**.
7.  Add a description, choose an expiry period, and click **Add**.
8.  **Immediately copy the secret's `Value`**. This is your only chance to see it. This is `pClientSecret`.

## Step 2: Grant Graph API Permissions

Now, grant the application permission to read SharePoint sites.

1.  In your app registration, go to **API permissions**.
2.  Click **+ Add a permission**, then select **Microsoft Graph**.
3.  Choose **Application permissions** (since ADF will run non-interactively).
4.  Search for and select `Sites.Read.All`. This allows the app to read all site collections. Alternatively, you can use `Files.Read.All` if you prefer.
5.  Click **Add permissions**.
6.  You will see the permission listed, but it requires administrator approval. Click the **Grant admin consent for [Your Tenant]** button and confirm.

    > **Note**: If you do not have permissions to grant admin consent, you will need to ask a tenant administrator to do so.

## Step 3: Identify Target SharePoint Site and Library

Identify the SharePoint site, document library, and folder containing the files you want to download.

*   **SharePoint Site**: e.g., `MyTeamSite`
*   **Document Library**: e.g., `Documents`
*   **Folder Path**: e.g., `/Source Files/Monthly Reports` (use `/` for the root)

## Step 4: Gather SharePoint IDs and Hostname

This is the most critical step. The Graph API uses specific IDs, not just names, to access resources.

1.  **SharePoint Host (`pSharePointHost`)**: This is your tenant's SharePoint domain. Example: `contoso.sharepoint.com`.

2.  **Site Name (`pSiteName`)**: The display name of your site. Example: `MyTeamSite`.

3.  **Library Name (`pLibraryName`)**: The display name of your document library. Example: `Documents`.

4.  **Site ID (`pSiteId`)**: To get the Site ID, use the following Graph API endpoint in your browser or a tool like Postman. You must be logged in to SharePoint in your browser.

    ```
    https://graph.microsoft.com/v1.0/sites/{pSharePointHost}:/sites/{site-name}
    ```

    **Example:**
    `https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/MyTeamSite`

    The response will be a JSON object. The `id` property is your `pSiteId`. It's a long string containing the hostname, site collection ID, and web ID.

5.  **Drive ID (`pDriveId`)**: To get the Drive ID (which represents the document library), use this endpoint:

    ```
    https://graph.microsoft.com/v1.0/sites/{pSiteId}/drives
    ```

    The response will be a list of drives (document libraries). Find the one with the correct name (e.g., `Documents`) and copy its `id` property. This is your `pDriveId`.

## Step 5: Deploy the Infrastructure

If you haven't already, deploy the Azure resources using either the **Deploy to Azure** button or the **CLI scripts** as described in the main [README.md](./../README.md).

## Step 6: Configure and Run the Pipeline

1.  Open your Data Factory in the Azure Portal and launch **ADF Studio**.
2.  If you haven't connected to your Git repository, do so now (**Manage** -> **Git configuration**).
3.  **Publish** all the factory resources.
4.  Navigate to the **Author** hub, select the `pl_spo_to_adls_downloadUrl` pipeline, and click **Debug**.
5.  Enter all the parameters you've collected:
    *   `pTenantId`
    *   `pClientId`
    *   `pClientSecret` (as a secure string)
    *   `pSiteId`
    *   `pSiteName`
    *   `pLibraryName`
    *   `pDriveId`
    *   `pFolderPath`
    *   `pSharePointHost`
    *   `pStorageAccountName` (the name of the ADLS account you're writing to)

6.  Click **OK** to start the pipeline run.

## Step 7: Verify ADLS Output

Once the pipeline succeeds, navigate to your ADLS Gen2 storage account using the Azure Portal's Storage Browser.

1.  Go to the `landing` container (or the one you specified in `pContainer`).
2.  You should see a folder structure matching the new format:

    `spo/site=<pSiteName>/library=<pLibraryName>/driveId=<pDriveId>/dt=<pRunDate>/`

3.  Inside this folder, you should find all the files from your specified SharePoint folder.

## Step 8: Validate Fallback Retry Logic

The pipeline is designed to handle expired download URLs. The initial URLs provided by the Graph API are short-lived. If a download fails, the pipeline attempts to get a fresh URL for that specific file and retries the download once.

To test this:

1.  Run the pipeline successfully once.
2.  Wait for an hour or so for the original download URLs to expire.
3.  Go to the **Monitor** hub in ADF Studio, find the previous pipeline run, and click **Rerun**.
4.  Observe the pipeline execution. You may see the initial `Copy_Download_HTTP` activity fail for some files, which will then trigger the `Copy_GetItem_RefreshUrl` and `Copy_Download_HTTP_RetryOnce` activities. The overall run should still succeed.
