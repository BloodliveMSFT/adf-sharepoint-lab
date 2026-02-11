# Architecture and Data Flow

This document explains the architecture of the ADF solution for downloading SharePoint files and the sequence of operations within the pipeline.

## Components

1.  **Azure Data Factory (ADF)**: The orchestrator for the entire process. It runs the pipeline, manages activities, and handles parameters.
2.  **System-Assigned Managed Identity (SAMI)**: The ADF instance has a managed identity enabled. This identity is used to securely authenticate with the Azure Data Lake Storage account, eliminating the need for storage keys.
3.  **Entra ID (Azure AD) App Registration**: A service principal that is granted permission to call the Microsoft Graph API. The pipeline uses its client ID and client secret to acquire an OAuth 2.0 token for Graph.
4.  **Microsoft Graph API**: The gateway to data and intelligence in Microsoft 365. The pipeline uses it for two main purposes:
    *   To list the files in a specific SharePoint document library folder.
    *   To get a temporary, pre-authenticated `downloadUrl` for each file.
5.  **Azure Data Lake Storage (ADLS) Gen2**: The destination for the downloaded files. It is configured with hierarchical namespace for optimized big data analytics workloads.

## Data Flow Diagram (Logical)

```
+-----------------------+
|   Entra ID App        |
| (Service Principal)   |
+-----------+-----------+
            | 1. Authenticate (Client Credentials)
            v
+-----------+-----------+
|   Microsoft Graph API |
+-----------+-----------+
            | 2. Get File List + Download URLs
            v
+--------------------------------------------------------------------+
| Azure Data Factory Pipeline (pl_spo_to_adls_downloadUrl)             |
|--------------------------------------------------------------------|
|                                                                    |
|  [Copy_Children_To_Meta] -> [Lookup_Meta] -> [Filter_Files]          |
|       |                                                            |
|       v                                                            |
|  [ForEach_Files] (Parallel Loop)                                   |
|       |                                                            |
|       |--> [Copy_Download_HTTP] --(on fail)--> [Get_Refresh_Url] --> [Retry_Download] |
|       |         |                                                    |
|       |         | 3. Download File (HTTP GET)                        |
|       v         v                                                    |
| +----------------------------------------------------------------+ |
| | Azure Data Lake Storage (ADLS Gen2)                            | |
| |----------------------------------------------------------------| |
| | - /meta (for temporary metadata)                               | |
| | - /landing (for final file output)                             | |
| +----------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+

```

## Pipeline Activity Sequence

The `pl_spo_to_adls_downloadUrl` pipeline executes the following steps:

1.  **Copy_Children_To_Meta (Copy Activity)**:
    *   **Source**: `ds_rest_graph_json` (REST Source). It calls the Graph API endpoint `.../children` to get a list of all items (files and folders) in the specified SharePoint folder (`pFolderPath`). This call uses the Entra App's credentials to authenticate.
    *   **Sink**: `ds_adls_meta_json` (JSON Sink). It writes the JSON array of file metadata returned by the Graph API to a temporary file in the `meta` container in ADLS.
    *   **Purpose**: To capture the full list of files and their properties, including the initial short-lived `downloadUrl`.

2.  **Lookup_Meta (Lookup Activity)**:
    *   Reads the JSON file created in the previous step from the `meta` container.
    *   **Purpose**: To load the file list into the pipeline's memory for iteration.

3.  **Filter_Files (Filter Activity)**:
    *   Iterates through the items from the `Lookup_Meta` activity.
    *   **Condition**: It only keeps items that are files (i.e., where the `file` property is not empty).
    *   **Purpose**: To ensure the pipeline only tries to download files, not folders.

4.  **ForEach_Files (ForEach Activity)**:
    *   This is the main loop that runs in parallel for each file found by the `Filter_Files` activity. The degree of parallelism is controlled by the `pConcurrency` parameter.
    *   Inside the loop, for each file item:

        a.  **Copy_Download_HTTP (Copy Activity)**:
            *   **Source**: `ds_http_binary` (HTTP Source). It uses the `@microsoft.graph.downloadUrl` from the file metadata to download the file content.
            *   **Sink**: `ds_adls_binary` (Binary Sink). It writes the file to the final destination in the `landing` container, using the new, structured path format: `landing/spo/site=<...>/library=<...>/...`
            *   **Purpose**: The primary download attempt.

        b.  **Copy_GetItem_RefreshUrl (Copy Activity - On Failure)**:
            *   This activity **only runs if `Copy_Download_HTTP` fails**. A common reason for failure is that the initial `downloadUrl` has expired.
            *   **Source**: `ds_rest_graph_json`. It makes a new Graph API call to the `.../items/{item-id}` endpoint to get fresh metadata for just this single file, which includes a new `downloadUrl`.
            *   **Sink**: `ds_adls_meta_json`. It writes this new metadata to a temporary file in the `spo_tmp` directory.
            *   **Purpose**: To get a fresh, valid download URL for a file that failed to download.

        c.  **Lookup_TempMeta (Lookup Activity)**:
            *   Reads the single-item metadata file created by the previous activity.
            *   **Purpose**: To load the refreshed `downloadUrl` into memory.

        d.  **Copy_Download_HTTP_RetryOnce (Copy Activity)**:
            *   This is the final download attempt.
            *   **Source**: `ds_http_binary`. It uses the newly retrieved `downloadUrl` from `Lookup_TempMeta`.
            *   **Sink**: `ds_adls_binary`. It writes to the same destination path as the initial attempt.
            *   **Purpose**: To complete the download using the refreshed URL.
