# ACC / BIM 360 Docs — Power BI Custom Connector

A custom Power BI connector for Autodesk Construction Cloud (ACC) and BIM 360 Docs that lets you query project files, folders, and file contents directly from Power BI using your own Autodesk credentials.

## What It Does

This connector authenticates via OAuth 2.0 against the Autodesk API and exposes a browsable navigation tree in Power BI:

**Hubs → Projects → Folders → Files → File Details / File Contents**

You can either browse interactively through the navigator or call actions directly from Power Query to pull specific data programmatically.

## Prerequisites

- [Power BI Desktop](https://powerbi.microsoft.com/desktop/)
- An [Autodesk Developer Account](https://aps.autodesk.com/)
- An Autodesk app with **client_id** and **client_secret** (see setup below)

## Setting Up Your Autodesk App

1. Go to the [Autodesk Platform Services Portal](https://aps.autodesk.com/) and sign in.
2. Create a new application (or use an existing one).
3. Under **API Access**, ensure the app has access to **Data Management API**.
4. Set the **Callback URL** to:
   ```
   https://oauth.powerbi.com/views/oauthredirect.html
   ```
5. Note down your **Client ID** and **Client Secret**.

## Installation

1. Clone or download this repository.
2. Create two files in the project root:
   - `client_id` — paste your Autodesk Client ID (plain text, no quotes, no newline)
   - `client_secret` — paste your Autodesk Client Secret (plain text, no quotes, no newline)
3. Build the connector using the [Power Query SDK](https://learn.microsoft.com/en-us/power-query/install-sdk) in Visual Studio or VS Code.
4. Copy the compiled `.mez` file to your Power BI custom connectors folder:
   ```
   Documents\Power BI Desktop\Custom Connectors\
   ```
   Create the folder if it doesn't exist.
5. In Power BI Desktop, go to **File → Options → Security** and set **Data Extensions** to *Allow any extension to load without warning* (or the recommended option with a warning).
6. Restart Power BI Desktop.

## Usage

### Navigator (Interactive)

1. In Power BI, go to **Get Data → Other → ACC BIM360 Docs**.
2. Authenticate with your Autodesk account via the OAuth prompt.
3. Browse through Hubs, Projects, and Folders to find your files.
4. Select the files you want to load.

### Direct Queries (Power Query)

You can call the connector directly with an action type and parameters:

```powerquery
ACC_BIM360_Docs.Contents(actionType, variableOne, variableTwo, variableThree, variableFour, variableFive)
```

#### Available Actions

| Action | Description | Var 1 | Var 2 | Var 3 | Var 4 | Var 5 |
|---|---|---|---|---|---|---|
| *(none)* | Returns all Hubs | — | — | — | — | — |
| `GetProjects` | List projects in a hub | Hub ID | — | — | — | — |
| `GetTopFolders` | Top-level folders in a project | Hub ID | Project ID | — | — | — |
| `GetFolders` | Child folders and Excel files | Project ID | Folder ID | — | — | — |
| `GetFiles` | Excel/CSV files in a folder | Project ID | Folder ID | — | — | — |
| `GetExcelFiles` | Same as GetFiles | Project ID | Folder ID | — | — | — |
| `GetAllFiles` | All file types in a folder | Project ID | Folder ID | — | — | — |
| `GetFileDetails` | Metadata for a specific file | Method* | Project ID | Item ID | URL | Version |
| `GetFileVersions` | Version history of a file | Project ID | Item ID | — | — | — |
| `DownloadFile` | Download file contents | Bucket Key | Object ID | File Type | — | — |
| `SearchFile` | Search files with filters | Project ID | Folder ID | Filter | Return Style | — |
| `OpenWebLink` | Parse an ACC web link | ACC URL | — | — | — | — |

*\*Method for GetFileDetails: `Tip` (latest), `Version` (specific version), or `URL` (direct link)*

#### Examples

```powerquery
// List all projects in a hub
= ACC_BIM360_Docs.Contents("GetProjects", "b.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")

// Get Excel files from a folder
= ACC_BIM360_Docs.Contents("GetFiles", "b.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "urn:adsk.wipprod:fs.folder:xxxxxxxxxx")

// Get latest version details from a web link
= ACC_BIM360_Docs.Contents("OpenWebLink", "https://acc.autodesk.com/docs/files/projects/...")
```

## Security

Your `client_id` and `client_secret` files are excluded from version control via `.gitignore`. **Never commit your credentials to Git.** Each user should create their own Autodesk app and supply their own credentials.

## OAuth Scopes

The connector requests the following scopes:

- `data:read` — Read access to project data, folders, and files
- `data:search` — Search files within folders

## License

This project is provided as-is for use with Autodesk ACC / BIM 360 Docs and Power BI.