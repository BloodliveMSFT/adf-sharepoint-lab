# Troubleshooting Guide

This guide covers common issues you might encounter when running the ADF to SharePoint lab.

## Authentication & Permissions (401/403 Errors)

Errors like `401 Unauthorized` or `403 Forbidden` when the pipeline calls the Graph API usually point to a problem with the Entra ID application registration or permissions.

| Symptom | Potential Cause | Solution |
|---|---|---|
| `401 Unauthorized` | Invalid client ID, tenant ID, or client secret. | 1. Double-check that the `pClientId`, `pTenantId`, and `pClientSecret` parameters in your pipeline run match the values from your Entra app registration. <br> 2. Ensure your client secret has not expired. Generate a new one if needed. |
| `403 Forbidden` | API permissions are missing or have not been granted admin consent. | 1. Go to your Entra app registration -> **API Permissions**. <br> 2. Verify that `Sites.Read.All` (or `Files.Read.All`) is listed under **Application permissions**. <br> 3. Check the status column. If it does not have a green checkmark, you must click the **Grant admin consent for [Your Tenant]** button. You may need an administrator to do this. |
| `403 Forbidden` | The service principal has been disabled. | Check the **Enterprise applications** section in Entra ID to ensure the service principal corresponding to your app registration is enabled. |

## SharePoint Path & ID Issues

Errors related to finding the site, drive, or folder.

| Symptom | Potential Cause | Solution |
|---|---|---|
| `404 Not Found` on the first Graph API call (`Copy_Children_To_Meta`) | Incorrect `pSiteId`, `pDriveId`, or `pFolderPath`. | 1. **Verify `pSiteId` and `pDriveId`**: Use the Graph API endpoints described in the [Lab Guide](./lab.md#step-4-gather-sharepoint-ids-and-hostname) to re-query the IDs. A common mistake is using the Site *Name* instead of the Site *ID*. <br> 2. **Check `pFolderPath`**: Ensure the path is correct and starts with a `/`. For the root of the library, use `/`. Folder paths are case-sensitive. <br> 3. **Verify `pSharePointHost`**: Make sure it is just the hostname (e.g., `contoso.sharepoint.com`), not a full URL. |
| Pipeline runs but finds no files (`Filter_Files` output is empty) | The `pFolderPath` is incorrect, or the folder is empty. | 1. Double-check the folder path in SharePoint. <br> 2. Ensure there are files (not just folders) in the target directory. The pipeline is configured to only copy files. |

## Download Failures

Issues occurring during the `Copy_Download_HTTP` or `Copy_Download_HTTP_RetryOnce` activities.

| Symptom | Potential Cause | Solution |
|---|---|---|
| `Host name mismatch` or SSL/TLS errors. | The `downloadUrl` provided by Graph API is for a different domain than the one configured in the `ls_http_spo_anon` linked service. | This is expected behavior. The pipeline is designed to handle this by stripping the host from the `downloadUrl` and using the `pSharePointHost` parameter as the base URL. If this fails, it indicates an issue with the `replace` expression in the `pRelativeUrl` parameter of the `ds_http_binary` dataset. Ensure it is: `@replace(string(item()["@microsoft.graph.downloadUrl"]), concat("https://", pipeline().parameters.pSharePointHost), "")` |
| `401 Unauthorized` on the download activity. | The `downloadUrl` has expired, and the retry logic also failed. | 1. This can happen if the pipeline is paused for a long time or if the retry fails for another reason. <br> 2. Check the output of the `Lookup_TempMeta` activity to ensure a new `downloadUrl` was successfully retrieved. <br> 3. A full re-run of the pipeline will fetch all-new URLs and should resolve the issue. |
| Throttling (`429 Too Many Requests` or `503 Service Unavailable`) | The pipeline is making too many requests to the Graph API or SharePoint in a short period. | 1. The `ForEach_Files` activity has a concurrency setting (`pConcurrency`). The default is 4. Try reducing this value to `2` or `1` to slow down the requests. <br> 2. The `Copy` activities have built-in retry logic that should handle intermittent throttling, but sustained throttling requires reducing concurrency. |

## ADLS Sink Issues

Problems writing data to the destination storage account.

| Symptom | Potential Cause | Solution |
|---|---|---|
| `403 AuthorizationPermissionMismatch` on the sink of the `Copy` activity. | The Data Factory's Managed Identity does not have the correct RBAC role on the storage account. | 1. Go to your ADLS Gen2 Storage Account in the Azure Portal. <br> 2. Navigate to **Access control (IAM)**. <br> 3. Click **Role assignments**. <br> 4. Verify that the Managed Identity of your Data Factory has the **Storage Blob Data Contributor** role assigned. <br> 5. If not, add the role assignment. The deployment script should do this automatically if you provide the `storageAccountId`. |
| `InvalidBlobOrBlock` or similar storage errors. | The storage account name is incorrect, or the account is not ADLS Gen2. | 1. Verify the `pStorageAccountName` parameter is correct. <br> 2. Ensure the storage account has **Hierarchical namespace** enabled (making it ADLS Gen2). |
