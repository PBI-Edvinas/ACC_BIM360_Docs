# ACC / BIM 360 Docs Power BI Connector — Documentation

A custom Power BI connector for Autodesk Construction Cloud (ACC) and BIM 360 Docs that enables direct access to project files, folders, and file contents from Power BI.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Authentication](#authentication)
5. [Usage Methods](#usage-methods)
   - [Navigator (Interactive Browsing)](#navigator-interactive-browsing)
   - [Direct Queries (Power Query)](#direct-queries-power-query)
6. [Action Reference](#action-reference)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This connector provides two ways to access your Autodesk cloud data:

1. **Navigator** — Browse through Hubs → Projects → Folders → Files interactively using Power BI's native navigation interface
2. **Direct Queries** — Call specific actions programmatically from Power Query with precise parameters

The connector uses OAuth 2.0 for authentication, meaning each user authenticates with their own Autodesk account and can only access data they have permissions for.

---

## Prerequisites

- [Power BI Desktop](https://powerbi.microsoft.com/desktop/)
- An [Autodesk Platform Services Account](https://aps.autodesk.com/) (formerly Forge)
- An Autodesk application with `client_id` and `client_secret`
- Access to BIM 360 or ACC projects

---

## Installation

### Step 1: Create an Autodesk Application

1. Go to the [Autodesk Platform Services Portal](https://aps.autodesk.com/)
2. Sign in or create an account
3. Create a new application
4. Under **API Access**, enable **Data Management API**
5. Set the **Callback URL** to:
   ```
   https://oauth.powerbi.com/views/oauthredirect.html
   ```
6. Save your **Client ID** and **Client Secret**

### Step 2: Configure the Connector

1. Clone or download this repository
2. In the project root, create two plain text files:
   - `client_id` — Contains only your Client ID (no quotes, no newline)
   - `client_secret` — Contains only your Client Secret (no quotes, no newline)

### Step 3: Build and Install

1. Open the project in Visual Studio with the [Power Query SDK](https://learn.microsoft.com/en-us/power-query/install-sdk)
2. Build the project (this creates a `.mez` file)
3. Copy the `.mez` file to:
   ```
   Documents\Power BI Desktop\Custom Connectors\
   ```
   Create this folder if it doesn't exist.

### Step 4: Enable Custom Connectors in Power BI

1. Open Power BI Desktop
2. Go to **File → Options and settings → Options**
3. Navigate to **Security → Data Extensions**
4. Select **(Not Recommended) Allow any extension to load without validation**
5. Restart Power BI Desktop

---

## Authentication

The connector uses OAuth 2.0 with the following scopes:

| Scope | Purpose |
|-------|---------|
| `data:read` | Read access to hubs, projects, folders, and files |
| `data:search` | Search files within folders |

When you first connect, Power BI will open a browser window for Autodesk login. After authentication, tokens are cached and refreshed automatically.

---

## Usage Methods

### Navigator (Interactive Browsing)

1. In Power BI, go to **Get Data → Other → ACC BIM360 Docs**
2. Authenticate with your Autodesk account
3. Browse the hierarchy:

```
Hubs
 └── Projects
      └── Top Folders
           └── Child Folders / Files
                └── FileDetails / FileContents
```

4. Select items and click **Load** or **Transform Data**

**Note:** When browsing folders, only Excel and CSV files are shown by default. Use `GetAllFiles` action for other file types.

### Direct Queries (Power Query)

For programmatic access, use the main function with an action type:

```powerquery
ACC_BIM360_Docs.Contents(actionType, var1, var2, var3, var4, var5)
```

All parameters after `actionType` are optional and vary by action.

---

## Action Reference

### Default (No Action) — Get Hubs

Returns all accessible hubs as a navigation table.

```powerquery
= ACC_BIM360_Docs.Contents()
```

**Returns:** Navigation table with Hub Name, Hub ID, and nested Projects

---

### GetProjects

Lists all projects within a hub.

| Parameter | Value |
|-----------|-------|
| actionType | `"GetProjects"` |
| var1 | Hub ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetProjects", "b.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
```

**Returns:** Navigation table with Project Name, Project ID, Root Folder ID

---

### GetTopFolders

Returns top-level folders in a project (e.g., "Project Files", "Plans").

| Parameter | Value |
|-----------|-------|
| actionType | `"GetTopFolders"` |
| var1 | Hub ID |
| var2 | Project ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetTopFolders", "b.hub-id-here", "b.project-id-here")
```

**Returns:** Navigation table with Folder Name, Folder ID

---

### GetFolders

Returns child folders and Excel/CSV files within a folder. Folders link to their contents; files link to FileDetails and FileContents.

| Parameter | Value |
|-----------|-------|
| actionType | `"GetFolders"` |
| var1 | Project ID |
| var2 | Folder ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetFolders", "b.project-id", "urn:adsk.wipprod:fs.folder:xxxxxx")
```

**Returns:** Navigation table combining folders and Excel/CSV files

---

### GetFiles / GetExcelFiles

Searches a folder recursively for Excel and CSV files only.

| Parameter | Value |
|-----------|-------|
| actionType | `"GetFiles"` or `"GetExcelFiles"` |
| var1 | Project ID |
| var2 | Folder ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetFiles", "b.project-id", "urn:adsk.wipprod:fs.folder:xxxxxx")
```

**Returns:** Table with file metadata (Name, CreateTime, CreateUserName, LastModifiedTime, LastModifiedUserName, VersionNumber, FileType, ItemID, BucketKey, ObjectID) plus navigation to FileDetails and FileContents

**Note:** `GetFiles` and `GetExcelFiles` are identical — `GetFiles` is kept for backward compatibility.

---

### GetAllFiles

Searches a folder recursively for ALL file types (not just Excel/CSV).

| Parameter | Value |
|-----------|-------|
| actionType | `"GetAllFiles"` |
| var1 | Project ID |
| var2 | Folder ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetAllFiles", "b.project-id", "urn:adsk.wipprod:fs.folder:xxxxxx")
```

**Returns:** Same structure as GetFiles, but includes all file types (PDFs, DWGs, RVTs, etc.)

---

### GetFileDetails

Returns metadata for a specific file version.

| Parameter | Value |
|-----------|-------|
| actionType | `"GetFileDetails"` |
| var1 | Method Type: `"Tip"`, `"Version"`, or `"URL"` |
| var2 | Project ID (for Tip/Version) |
| var3 | Item ID (for Tip/Version) |
| var4 | Direct URL (for URL method) |
| var5 | Version Number (for Version method) |

**Method Types:**

| Method | Description | Required Parameters |
|--------|-------------|---------------------|
| `Tip` | Get latest version | var2 (Project ID), var3 (Item ID) |
| `Version` | Get specific version | var2, var3, var5 (Version Number) |
| `URL` | Use direct API URL | var4 (Full URL) |

```powerquery
// Get latest version
= ACC_BIM360_Docs.Contents("GetFileDetails", "Tip", "b.project-id", "urn:adsk.wipprod:dm.lineage:xxxxx")

// Get specific version
= ACC_BIM360_Docs.Contents("GetFileDetails", "Version", "b.project-id", "urn:adsk.wipprod:dm.lineage:xxxxx", null, "3")
```

**Returns:** Table with File ID, File Name, Version, Created By, Created At, Last Modified By, Last Modified At, File Type, Bucket Key, Object ID

---

### GetFileVersions

Returns the complete version history of a file.

| Parameter | Value |
|-----------|-------|
| actionType | `"GetFileVersions"` |
| var1 | Project ID |
| var2 | Item ID |

```powerquery
= ACC_BIM360_Docs.Contents("GetFileVersions", "b.project-id", "urn:adsk.wipprod:dm.lineage:xxxxx")
```

**Returns:** Table with all versions including File ID, FileName, LastModifiedAt, LastModifiedBy, VersionNumber, FileType, Storage ID, BucketKey, ObjectID

---

### DownloadFile

Downloads and parses file contents. Automatically detects Excel workbooks and CSV files.

| Parameter | Value |
|-----------|-------|
| actionType | `"DownloadFile"` |
| var1 | Bucket Key |
| var2 | Object ID |
| var3 | File Type (optional, for parsing hints) |

```powerquery
= ACC_BIM360_Docs.Contents("DownloadFile", "wip.dm.prod", "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "xlsx")
```

**Returns:** 
- For Excel files: Workbook object with sheets
- For CSV files: Parsed table
- For other files: Raw binary content

---

### SearchFile

Searches for files with custom filter parameters.

| Parameter | Value |
|-----------|-------|
| actionType | `"SearchFile"` |
| var1 | Project ID |
| var2 | Folder ID |
| var3 | Filter Query String |
| var4 | Return Style: `"Table"` or `"Boolean"` |

```powerquery
// Search for specific file types
= ACC_BIM360_Docs.Contents("SearchFile", "b.project-id", "urn:adsk.wipprod:fs.folder:xxxxx", "filter[fileType]=rvt,dwg")

// Check if files exist (returns true/false)
= ACC_BIM360_Docs.Contents("SearchFile", "b.project-id", "urn:adsk.wipprod:fs.folder:xxxxx", "filter[fileType]=pdf", "Boolean")
```

**Filter Examples:**
- `filter[fileType]=xlsx,csv` — Filter by file type
- `filter[name]=Report` — Filter by name contains
- `filter[lastModifiedTime]=2024-01-01..2024-12-31` — Filter by date range

**Returns:** 
- `"Table"` (default): File metadata table
- `"Boolean"`: `true` if files found, `false` if empty

---

### OpenWebLink

Parses an ACC/BIM 360 web URL and returns file details.

| Parameter | Value |
|-----------|-------|
| actionType | `"OpenWebLink"` |
| var1 | ACC Web URL |

```powerquery
= ACC_BIM360_Docs.Contents("OpenWebLink", "https://acc.autodesk.com/docs/files/projects/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx?folderUrn=xxx&entityId=xxx")
```

**Returns:** File details table (same as GetFileDetails with Tip method)

**Use Case:** When someone shares an ACC link, paste it directly to get file metadata without manually extracting IDs.

---

## Examples

### Example 1: Load All Excel Files from a Project Folder

```powerquery
let
    // Get Excel files from a specific folder
    Files = ACC_BIM360_Docs.Contents(
        "GetFiles", 
        "b.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  // Project ID
        "urn:adsk.wipprod:fs.folder:xxxxxxxxxx"    // Folder ID
    ),
    // Expand to get file contents
    FileData = Table.SelectRows(Files, each [Name] = "MonthlyReport.xlsx"),
    Contents = FileData{0}[Data],
    Sheet1 = Contents{[Item="Sheet1"]}[Data]
in
    Sheet1
```

### Example 2: Get Latest Version of a File from Web Link

```powerquery
let
    // Paste the ACC link directly
    FileInfo = ACC_BIM360_Docs.Contents(
        "OpenWebLink",
        "https://acc.autodesk.com/docs/files/projects/abc123?folderUrn=xyz&entityId=urn%3Aadsk.wipprod%3Adm.lineage%3Adef456"
    ),
    // Extract bucket and object keys for download
    BucketKey = FileInfo{0}[Bucket Key],
    ObjectID = FileInfo{0}[Object ID],
    // Download the file
    FileContents = ACC_BIM360_Docs.Contents("DownloadFile", BucketKey, ObjectID)
in
    FileContents
```

### Example 3: Check if Folder Contains PDFs

```powerquery
let
    HasPDFs = ACC_BIM360_Docs.Contents(
        "SearchFile",
        "b.project-id",
        "urn:adsk.wipprod:fs.folder:xxxxx",
        "filter[fileType]=pdf",
        "Boolean"
    )
in
    if HasPDFs then "PDFs found" else "No PDFs"
```

### Example 4: Get Complete Version History

```powerquery
let
    Versions = ACC_BIM360_Docs.Contents(
        "GetFileVersions",
        "b.project-id",
        "urn:adsk.wipprod:dm.lineage:xxxxx"
    ),
    // Sort by version number descending
    Sorted = Table.Sort(Versions, {{"VersionNumber", Order.Descending}})
in
    Sorted
```

---

## Troubleshooting

### "Access Denied" or 403 Errors

- Verify your Autodesk account has access to the project
- Check that the app is provisioned to the BIM 360/ACC account (requires Account Admin)
- Ensure OAuth scopes include `data:read` and `data:search`

### "Invalid Client" Error

- Verify `client_id` and `client_secret` files contain correct values
- Check for trailing newlines or spaces in the credential files
- Ensure the callback URL matches exactly: `https://oauth.powerbi.com/views/oauthredirect.html`

### Empty Results

- Confirm the folder contains files of the expected type
- For `GetFiles`/`GetExcelFiles`, only Excel and CSV files are returned
- Use `GetAllFiles` for other file types

### Token Refresh Issues

- Clear cached credentials: **File → Options → Data source settings → Clear Permissions**
- Re-authenticate

### Files Not Loading

- Large files may timeout — check Power BI timeout settings
- Some file types (e.g., RVT, DWG) return binary data and cannot be parsed directly

---

## Security Notes

- **Never commit credentials** — `client_id` and `client_secret` files are gitignored
- Each user should create their own Autodesk app for their organization
- Tokens are stored locally by Power BI and refreshed automatically
- The connector only accesses data the authenticated user has permissions for

---

## Version History

| Version | Changes |
|---------|---------|
| 2.0.0 | Current version — Full ACC/BIM 360 Docs support |

---

## License

This connector is provided as-is for integration with Autodesk ACC/BIM 360 Docs and Power BI.