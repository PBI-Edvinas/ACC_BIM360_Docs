// This file contains your Data Connector logic
[Version = "2.0.0"]
section ACC_BIM360_Docs;

// API credentials
client_id = Text.FromBinary(Extension.Contents("client_id")); 
client_secret = Text.FromBinary(Extension.Contents("client_secret")); 

// static variables required for OAuth
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
authorization_uri = "https://developer.api.autodesk.com/authentication/v2/authorize";
token_uri = "https://developer.api.autodesk.com/authentication/v2/token";
base_api_uri = "https://developer.api.autodesk.com/data/v1/";

// static variables for OAuth window size
windowHeight = 775;
windowWidth = 650;

// api query variables ??
url_hubs = "https://developer.api.autodesk.com/project/v1/hubs";

[DataSource.Kind="ACC_BIM360_Docs", Publish="ACC_BIM360_Docs.Publish"]
shared ACC_BIM360_Docs.Contents = (optional actionType as nullable text, optional variableOne as nullable text, optional variableTwo as nullable text, optional variableThree as nullable text, optional variableFour as nullable text, optional variableFive as nullable text) =>
    let
        output = 
            if 
                actionType = "GetProjects" 
            then 
                ACC_BIM360_Docs.Projects(variableOne)
            else if 
                actionType = "GetTopFolders"
            then 
                ACC_BIM360_Docs.Folders(variableOne, variableTwo)
            else if 
                actionType = "GetFolders"
            then 
                ACC_BIM360_Docs.ChildFolders(variableOne, variableTwo)
            else if
                // "GetExcelFiles" is the new name; "GetFiles" kept for backward compatibility
                actionType = "GetFiles" or actionType = "GetExcelFiles"
            then
                ACC_BIM360_Docs.Files(variableOne, variableTwo)
            else if
                actionType = "GetAllFiles"
            then
                ACC_BIM360_Docs.AllFiles(variableOne, variableTwo)
            else if
                actionType = "GetFileDetails"
            then
                ACC_BIM360_Docs.FileDetails(variableOne, variableTwo, variableThree, variableFour, variableFive)
            else if
                actionType = "GetFileVersions"
            then
                ACC_BIM360_Docs.FileVersionHistory(variableOne, variableTwo)
            else if
                actionType = "DownloadFile"
            then
                ACC_BIM360_Docs.FileContents(variableOne, variableTwo, variableThree)
            else if
                actionType = "SearchFile"
            then
                ACC_BIM360_Docs.SearchFile(variableOne, variableTwo, variableThree, variableFour)
            else if 
                actionType = "OpenWebLink"
            then
                ACC_BIM360_Docs.OpenWebLink(variableOne)
            else
                ACC_BIM360_Docs.Hubs()
    in
        output;

ACC_BIM360_Docs.Hubs = () =>
    let
        // URL to fetch hubs
        url = url_hubs,
        // Fetch the data from the URL
        source = Web.Contents(url),
        // Parse the JSON response
        jsonResponse = Json.Document(source),
        // Extract the hubs data
        hubs = jsonResponse[data],
        // Convert the hubs data to a table
        hubsTable = Table.FromList(hubs, Splitter.SplitByNothing(), {"Hub"}),
        // Expand the attributes column to get the hub names and IDs
        expandedHubsTable = Table.ExpandRecordColumn(hubsTable, "Hub", {"attributes", "id"}, {"attributes", "Hub ID"}),
        expandedAttributesTable = Table.ExpandRecordColumn(expandedHubsTable, "attributes", {"name"}, {"Hub Name"}),
        // Create a navigation table
        sourceTable = Table.AddColumn(expandedAttributesTable, "Data", each ACC_BIM360_Docs.Projects([Hub ID])),
        sourceTableWithNav = Table.AddColumn(sourceTable, "ItemKind", each "Folder"),
        sourceTableWithNav2 = Table.AddColumn(sourceTableWithNav, "ItemName", each "Folder"),
        sourceTableWithNav3 = Table.AddColumn(sourceTableWithNav2, "IsLeaf", each false),
        navTable = Table.ToNavigationTable(sourceTableWithNav3, {"Hub ID"}, "Hub Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

ACC_BIM360_Docs.Projects = (hubId as text) =>
    let
        // Function to get a single page of projects
        GetProjectsPage = (pageNumber as nullable number) as nullable table =>
            let
                // Set the page number to 0 if it's null (first call)
                page = if pageNumber = null then 0 else pageNumber,
                // Construct the URL with pagination parameters
                url = "https://developer.api.autodesk.com/project/v1/hubs/" & hubId & "/projects?page[number]=" & Text.From(page) & "&page[limit]=200",
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                projects = jsonResponse[data],
                // Convert the data array to a table
                projectsTable = if projects = null then null else Table.FromList(projects, Splitter.SplitByNothing(), {"Project"}),
                // Expand the project records into columns
                expandedProjectsTable = if projectsTable = null then null else Table.ExpandRecordColumn(projectsTable, "Project", {"id", "attributes", "relationships"}, {"Project ID", "attributes", "relationships"}),
                expandedAttributesTable = if expandedProjectsTable = null then null else Table.ExpandRecordColumn(expandedProjectsTable, "attributes", {"name"}, {"Project Name"}),
                expandedRelationshipsTable = if expandedAttributesTable = null then null else Table.ExpandRecordColumn(expandedAttributesTable, "relationships", {"rootFolder"}, {"rootFolder"}),
                expandedRootFolderTable = if expandedRelationshipsTable = null then null else Table.ExpandRecordColumn(expandedRelationshipsTable, "rootFolder", {"data"}, {"rootFolderData"}),
                expandedRootFolderDataTable = if expandedRootFolderTable = null then null else Table.ExpandRecordColumn(expandedRootFolderTable, "rootFolderData", {"id"}, {"Root Folder ID"})
            in
                // Return the expanded table or null if no data
                if expandedRootFolderDataTable = null or Table.IsEmpty(expandedRootFolderDataTable) then null else expandedRootFolderDataTable,

        // Function to fetch all pages of projects
        GetAllProjects = (hubId as text) as table =>
            let
                // Initialize the page number
                initialPage = 0,
                // Function to recursively fetch all pages
                FetchPages = (pageNumber as number, accumulatedTable as table) as table =>
                    let
                        // Fetch the current page
                        currentPage = GetProjectsPage(pageNumber),
                        // Check if the current page is null or empty
                        newAccumulatedTable = if currentPage = null then accumulatedTable else Table.Combine({accumulatedTable, currentPage}),
                        // Check if we need to fetch the next page
                        nextPage = if currentPage = null or Table.IsEmpty(currentPage) then null else pageNumber + 1
                    in
                        // Recursively fetch the next page if it exists
                        if nextPage = null then newAccumulatedTable else @FetchPages(nextPage, newAccumulatedTable),

                // Start fetching from the initial page
                allProjects = FetchPages(initialPage, #table({}, {}))
            in
                allProjects,

        // Fetch all projects
        allProjects = GetAllProjects(hubId),
        // Add navigation columns
        projectsWithNav = Table.AddColumn(allProjects, "Data", each ACC_BIM360_Docs.Folders(hubId, [Project ID])),
        projectsWithNav2 = Table.AddColumn(projectsWithNav, "ItemKind", each "Folder"),
        projectsWithNav3 = Table.AddColumn(projectsWithNav2, "ItemName", each "Folder"),
        projectsWithNav4 = Table.AddColumn(projectsWithNav3, "IsLeaf", each false),
        navTable = Table.ToNavigationTable(projectsWithNav4, {"Project ID"}, "Project Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

ACC_BIM360_Docs.Folders = (hubId as text, projectId as text) =>
    let
        // Construct the URL for top folders
        url = "https://developer.api.autodesk.com/project/v1/hubs/" & hubId & "/projects/" & projectId & "/topFolders",
        // Fetch the data from the API
        source = Web.Contents(url),
        // Parse the JSON response
        jsonResponse = Json.Document(source),
        // Extract the data array
        folders = jsonResponse[data],
        // Convert the data array to a table
        foldersTable = if folders = null then null else Table.FromList(folders, Splitter.SplitByNothing(), {"Folder"}),
        // Expand the folder records into columns
        expandedFoldersTable = if foldersTable = null then null else Table.ExpandRecordColumn(foldersTable, "Folder", {"id", "attributes", "relationships"}, {"Folder ID", "attributes", "relationships"}),
        expandedAttributesTable = if expandedFoldersTable = null then null else Table.ExpandRecordColumn(expandedFoldersTable, "attributes", {"name"}, {"Folder Name"}),
        // Add navigation columns
        foldersWithNav = Table.AddColumn(expandedAttributesTable, "Data", each ACC_BIM360_Docs.ChildFolders(projectId, [Folder ID])),
        foldersWithNav2 = Table.AddColumn(foldersWithNav, "ItemKind", each "Folder"),
        foldersWithNav3 = Table.AddColumn(foldersWithNav2, "ItemName", each "Folder"),
        foldersWithNav4 = Table.AddColumn(foldersWithNav3, "IsLeaf", each false),
        navTable = Table.ToNavigationTable(foldersWithNav4, {"Folder ID"}, "Folder Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

ACC_BIM360_Docs.ChildFolders = (projectId as text, folderId as text) =>
    let
        // Recursive function to fetch all pages of child folders and files
        FetchContents = (projectId as text, folderId as text, nextPage as nullable text) =>
            let
                // Construct the URL for child folders and files
                url = if nextPage = null then "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/folders/" & folderId & "/contents" else nextPage,
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                data = jsonResponse[data],
                // Extract the next page URL
                nextPageUrl = try jsonResponse[links][next][href] otherwise null,
                // Fetch the next page if it exists
                nextPageData = if nextPageUrl <> null then @FetchContents(projectId, folderId, nextPageUrl) else {},
                // Combine the current page data with the next page data
                combinedData = List.Combine({data, nextPageData})
            in
                combinedData,

        // Fetch all contents (folders and files)
        allContents = FetchContents(projectId, folderId, null),

        // Separate folders and files
        folders = List.Select(allContents, each _[type] = "folders"),
        files = List.Select(allContents, each _[type] = "items"),

        // Convert the folders array to a table
        foldersTable = if folders = null then null else Table.FromList(folders, Splitter.SplitByNothing(), {"Folder"}),
        // Expand the folder records into columns
        expandedFoldersTable = if foldersTable = null then null else Table.ExpandRecordColumn(foldersTable, "Folder", {"id", "attributes"}, {"ID", "attributes"}),
        // Duplicate the attributes column
        duplicatedfoldersAttributesColumn = if expandedFoldersTable = null then null else Table.DuplicateColumn(expandedFoldersTable, "attributes", "attributes_copy"),
        // Expand the duplicated attributes column to get the name column
        expandedFoldersAttributesTable = if duplicatedfoldersAttributesColumn = null then null else Table.ExpandRecordColumn(duplicatedfoldersAttributesColumn, "attributes_copy", {"name"}, {"Name"}),
        // Reorder the columns
        reOrderFoldersAttributesTable = if expandedFoldersAttributesTable = null then null else Table.ReorderColumns(expandedFoldersAttributesTable, {"ID", "Name", "attributes"}),

        // Add navigation columns for folders
        foldersWithNav = Table.AddColumn(reOrderFoldersAttributesTable, "Data", each ACC_BIM360_Docs.Files(projectId, [ID])),
        foldersWithNav2 = Table.AddColumn(foldersWithNav, "ItemKind", each "Folder"),
        foldersWithNav3 = Table.AddColumn(foldersWithNav2, "ItemName", each [Name]),
        foldersWithNav4 = Table.AddColumn(foldersWithNav3, "IsLeaf", each false),

        // -----------------------------------------------------------------------------------------------
        filesTable = if files = null then null else Table.FromList(files, Splitter.SplitByNothing(), {"File"}),

        // Expand the attributes and relationships columns
        expandedFilesTable = if filesTable = null then null else Table.ExpandRecordColumn(filesTable, "File", {"id", "attributes", "relationships"}, {"ID", "attributes", "relationships"}),
        // Duplicate the attributes column
        duplicatedFilesAttributesColumn = if expandedFilesTable = null then null else Table.DuplicateColumn(expandedFilesTable, "attributes", "attributes_copy"),
        expandedAttributesTable = if duplicatedFilesAttributesColumn = null then null else Table.ExpandRecordColumn(duplicatedFilesAttributesColumn, "attributes_copy", {"displayName"}, {"Name"}),

        // Filter out the files that are not Excel files or CSV files
        FilteredRows = Table.SelectRows(expandedAttributesTable, each (
            Text.EndsWith([Name], ".xlsx") or
            Text.EndsWith([Name], ".xlsm") or
            Text.EndsWith([Name], ".xlsb") or
            Text.EndsWith([Name], ".xls") or
            Text.EndsWith([Name], ".csv")
        )),

        expandedRelationshipsTable = if FilteredRows = null then null else Table.ExpandRecordColumn(FilteredRows, "relationships", {"tip"}, {"tip"}),
        expandedTipTable = if expandedRelationshipsTable = null then null else Table.ExpandRecordColumn(expandedRelationshipsTable, "tip", {"links"}, {"links"}),
        expandedLinkTable = if expandedTipTable = null then null else Table.ExpandRecordColumn(expandedTipTable, "links", {"related"}, {"related"}),
        expandedRelatedTable = if expandedLinkTable = null then null else Table.ExpandRecordColumn(expandedLinkTable, "related", {"href"}, {"item_link"}),

        createFileNavTable = (itemLink as text) as table =>
        let
            objects = #table(
                {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
                {
                    {"FileDetails", "fileDetails", ACC_BIM360_Docs.FileDetails("URL", null, null, itemLink, null), "View", "Table", true},
                    {"FileContents", "fileContents", ACC_BIM360_Docs.FileContents(null, null, null, itemLink), "Sheet", "Table", true}
                }
            ),
            navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        in
            navTable,

        // Add navigation columns with File Name as a folder
        filesWithNav = Table.AddColumn(expandedRelatedTable, "Data", each createFileNavTable([item_link])),
        filesWithNav2 = Table.AddColumn(filesWithNav, "ItemKind", each "Table"),
        filesWithNav3 = Table.AddColumn(filesWithNav2, "ItemName", each [Name]),
        filesWithNav4 = Table.AddColumn(filesWithNav3, "IsLeaf", each false),    

        //clean up columns
        removeColumns = Table.RemoveColumns(filesWithNav4, {"item_link"}),
        // -----------------------------------------------------------------------------------------------

        // Combine folders and files into a single table
        combinedTable = Table.Combine({foldersWithNav4, removeColumns}),

        // Convert to Navigation Table
        navTable = Table.ToNavigationTable(combinedTable, {"ID"}, "ItemName", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

ACC_BIM360_Docs.Files = (projectId as text, folderId as text) =>
    let
        // Recursive function to fetch files with pagination
        FetchFiles = (projectId as text, folderId as text, nextPage as nullable text) =>
            let
                // Construct the URL for files with file type filter and pagination
                url = if nextPage = null then "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/folders/" & folderId & "/search?filter[fileType]=xlsx,xlsm,xlsb,xls,csv" else nextPage,
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                data = jsonResponse[data],
                // Check if the data array is not empty
                nextPageUrl = try jsonResponse[links][next][href] otherwise null,
                // Fetch the next page if it exists
                nextPageData = if nextPageUrl <> null then @FetchFiles(projectId, folderId, nextPageUrl) else {},
                // Combine the results from all pages
                combinedData = List.Combine({data, nextPageData})
            in
                combinedData,       

        // Fetch all files
        allFiles = FetchFiles(projectId, folderId, null),
        filesTable = if allFiles = null then null else Table.FromList(allFiles, Splitter.SplitByNothing(), {"File"}),

        // Expand the attributes and relationships columns
        expandedFilesTable = if filesTable = null then null else Table.ExpandRecordColumn(filesTable, "File", {"attributes", "relationships"}, {"attributes", "relationships"}),
        expandedAttributesTable = if expandedFilesTable = null then null else Table.ExpandRecordColumn(expandedFilesTable, "attributes", {"name", "createTime", "createUserName", "lastModifiedTime", "lastModifiedUserName", "versionNumber", "fileType"}, {"Name", "CreateTime", "CreateUserName", "LastModifiedTime", "LastModifiedUserName", "VersionNumber", "FileType"}),
        expandedRelationshipsTable = if expandedAttributesTable = null then null else Table.ExpandRecordColumn(expandedAttributesTable, "relationships", {"item", "storage"}, {"item", "storage"}),

        // Expand the item and storage columns
        expandedItemTable = if expandedRelationshipsTable = null then null else Table.ExpandRecordColumn(expandedRelationshipsTable, "item", {"data"}, {"data"}),
        expandedItemDataTable = if expandedItemTable = null then null else Table.ExpandRecordColumn(expandedItemTable, "data", {"id"}, {"ItemID"}),
        expandedStorageTable = if expandedItemDataTable = null then null else Table.ExpandRecordColumn(expandedItemDataTable, "storage", {"data"}, {"data"}),
        expandedStorageDataTable = if expandedStorageTable = null then null else Table.ExpandRecordColumn(expandedStorageTable, "data", {"id"}, {"Storage ID"}),

        // Extract bucket key and object ID from Storage ID
        addBucketKey = Table.AddColumn(expandedStorageDataTable, "BucketKey", each Text.Middle(Text.Split([Storage ID], ":"){3}, 0, Text.PositionOf(Text.Split([Storage ID], ":"){3}, "/"))),
        addObjectId = Table.AddColumn(addBucketKey, "ObjectID", each Text.AfterDelimiter([Storage ID], "/")),

        // remove Storage ID column
        removeStorageId = Table.RemoveColumns(addObjectId, {"Storage ID"}),

        // Create nested navigation table for each file
        createFileNavTable = (projectId as text, fileName as text, version as text, bucketKey as text, objectId as text, itemId as text, fileType as text) as table =>
            let
                objects = #table(
                    {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
                    {
                        {"FileDetails", "fileDetails", ACC_BIM360_Docs.FileDetails("Tip", projectId, itemId), "View", "Table", true},
                        {"FileContents", "fileContents", ACC_BIM360_Docs.FileContents(bucketKey, objectId, fileType), "Sheet", "Table", true}
                    }
                ),
                navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in
                navTable,

        // Add navigation columns with File Name as a folder
        filesWithNav = Table.AddColumn(removeStorageId, "Data", each createFileNavTable(projectId, [Name], Text.From([VersionNumber]), [BucketKey], [ObjectID], [ItemID], [FileType])),
        filesWithNav2 = Table.AddColumn(filesWithNav, "ItemKind", each "Table"),
        filesWithNav3 = Table.AddColumn(filesWithNav2, "ItemName", each [Name]),
        filesWithNav4 = Table.AddColumn(filesWithNav3, "IsLeaf", each false),

        // Convert to Navigation Table
        navTable = Table.ToNavigationTable(filesWithNav4, {"ItemID"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

ACC_BIM360_Docs.AllFiles = (projectId as text, folderId as text) =>
    let
        // Recursive function to fetch files with pagination
        FetchFiles = (projectId as text, folderId as text, nextPage as nullable text) =>
            let
                // Construct the URL for files with file type filter and pagination
                url = if nextPage = null then "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/folders/" & folderId & "/search" else nextPage,
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                data = jsonResponse[data],
                // Check if the data array is not empty
                nextPageUrl = try jsonResponse[links][next][href] otherwise null,
                // Fetch the next page if it exists
                nextPageData = if nextPageUrl <> null then @FetchFiles(projectId, folderId, nextPageUrl) else {},
                // Combine the results from all pages
                combinedData = List.Combine({data, nextPageData})
            in
                combinedData,       

        // Fetch all files
        allFiles = FetchFiles(projectId, folderId, null),
        filesTable = if allFiles = null then null else Table.FromList(allFiles, Splitter.SplitByNothing(), {"File"}),

        // Expand the attributes and relationships columns
        expandedFilesTable = if filesTable = null then null else Table.ExpandRecordColumn(filesTable, "File", {"attributes", "relationships"}, {"attributes", "relationships"}),
        expandedAttributesTable = if expandedFilesTable = null then null else Table.ExpandRecordColumn(expandedFilesTable, "attributes", {"name", "createTime", "createUserName", "lastModifiedTime", "lastModifiedUserName", "versionNumber", "fileType"}, {"Name", "CreateTime", "CreateUserName", "LastModifiedTime", "LastModifiedUserName", "VersionNumber", "FileType"}),
        expandedRelationshipsTable = if expandedAttributesTable = null then null else Table.ExpandRecordColumn(expandedAttributesTable, "relationships", {"item", "storage"}, {"item", "storage"}),

        // Expand the item and storage columns
        expandedItemTable = if expandedRelationshipsTable = null then null else Table.ExpandRecordColumn(expandedRelationshipsTable, "item", {"data"}, {"data"}),
        expandedItemDataTable = if expandedItemTable = null then null else Table.ExpandRecordColumn(expandedItemTable, "data", {"id"}, {"ItemID"}),
        expandedStorageTable = if expandedItemDataTable = null then null else Table.ExpandRecordColumn(expandedItemDataTable, "storage", {"data"}, {"data"}),
        expandedStorageDataTable = if expandedStorageTable = null then null else Table.ExpandRecordColumn(expandedStorageTable, "data", {"id"}, {"Storage ID"}),

        // Extract bucket key and object ID from Storage ID
        addBucketKey = Table.AddColumn(expandedStorageDataTable, "BucketKey", each Text.Middle(Text.Split([Storage ID], ":"){3}, 0, Text.PositionOf(Text.Split([Storage ID], ":"){3}, "/"))),
        addObjectId = Table.AddColumn(addBucketKey, "ObjectID", each Text.AfterDelimiter([Storage ID], "/")),

        // remove Storage ID column
        removeStorageId = Table.RemoveColumns(addObjectId, {"Storage ID"}),

        // Create nested navigation table for each file
        createFileNavTable = (projectId as text, fileName as text, version as text, bucketKey as text, objectId as text, itemId as text, fileType as text) as table =>
            let
                objects = #table(
                    {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
                    {
                        {"FileDetails", "fileDetails", ACC_BIM360_Docs.FileDetails("Tip", projectId, itemId), "View", "Table", true},
                        {"FileContents", "fileContents", ACC_BIM360_Docs.FileContents(bucketKey, objectId, fileType), "Sheet", "Table", true}
                    }
                ),
                navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in
                navTable,

        // Add navigation columns with File Name as a folder
        filesWithNav = Table.AddColumn(removeStorageId, "Data", each createFileNavTable(projectId, [Name], Text.From([VersionNumber]), [BucketKey], [ObjectID], [ItemID], [FileType])),
        filesWithNav2 = Table.AddColumn(filesWithNav, "ItemKind", each "Table"),
        filesWithNav3 = Table.AddColumn(filesWithNav2, "ItemName", each [Name]),
        filesWithNav4 = Table.AddColumn(filesWithNav3, "IsLeaf", each false),

        // Convert to Navigation Table
        navTable = Table.ToNavigationTable(filesWithNav4, {"ItemID"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Function to get file contents
ACC_BIM360_Docs.FileContents = (optional bucketKey as nullable text, optional objectKey as nullable text, optional fileType as nullable text, optional fileTipLink as nullable text) =>
    let
        
        fileDetails = if fileTipLink <> null then Json.Document(Web.Contents(fileTipLink)) else null,
        fileDetails_versionData = if fileTipLink <> null then try fileDetails[data]{0} otherwise try fileDetails[data] otherwise null else null,
        fileDetails_storageData = if fileTipLink <> null then fileDetails_versionData[relationships][storage][data] else null,
        fileDetails_bucketKey = if fileTipLink <> null then Text.Middle(Text.Split(fileDetails_storageData[id], ":"){3}, 0, Text.PositionOf(Text.Split(fileDetails_storageData[id], ":"){3}, "/")) else null,
        fileDetails_objectKey = if fileTipLink <> null then Text.AfterDelimiter(fileDetails_storageData[id], "/") else null,

        bucketKeyPlaceholder = 
            if fileTipLink <> null then
                fileDetails_bucketKey
            else
                bucketKey,
        
        objectKeyPlaceholder =
            if fileTipLink <> null then
                fileDetails_objectKey
            else
                objectKey,

        // Construct the URL for file contents
        url = "https://developer.api.autodesk.com/oss/v2/buckets/" & bucketKeyPlaceholder & "/objects/" & objectKeyPlaceholder,
        // Fetch the data from the API
        source = Web.Contents(url),
        // Convert the binary data to text
        contents = try Excel.Workbook(source) otherwise try Csv.Document(source, [Delimiter = ",", Encoding = 1252, QuoteStyle = QuoteStyle.None]) otherwise source
    in
        contents;

// Function to get file details
ACC_BIM360_Docs.FileDetails = (methodType as text, optional projectId as nullable text, optional itemId as nullable text, optional url as nullable text, optional version as nullable text) =>
    let

        // get relative path based on method type
        relativePath = 
            if methodType = "Tip" then
                base_api_uri & "projects/" & projectId & "/items/" & itemId & "/tip"
            else if methodType = "Version" then
                base_api_uri & "projects/" & projectId & "/items/" & itemId & "/versions?filter[versionNumber]=" & version
            else if methodType = "URL" then
                url
            else 
                null,

         // Fetch the data from the API
        source = Web.Contents(relativePath),
        // Parse the JSON response
        jsonResponse = Json.Document(source),
        // Extract the data array
        versionData = try jsonResponse[data]{0} otherwise try jsonResponse[data] otherwise null,

        attributes = versionData[attributes],
        storageData = versionData[relationships][storage][data],
        bucketKey = Text.Middle(Text.Split(storageData[id], ":"){3}, 0, Text.PositionOf(Text.Split(storageData[id], ":"){3}, "/")),
        objectKey = Text.AfterDelimiter(storageData[id], "/"),

        // Create the details table
        details = #table(
            {"File ID", "File Name", "Version", "Created By", "Created At", "Last Modified By", "Last Modified At", "File Type", "Bucket Key", "Object ID"},
            {{versionData[relationships][item][data][id], attributes[name], attributes[versionNumber], attributes[createUserName], attributes[createTime], attributes[lastModifiedUserName], attributes[lastModifiedTime], attributes[fileType], bucketKey, objectKey}}
        )
        
    in
        details;

// Function to get file details
ACC_BIM360_Docs.FileVersionHistory = (projectId as text, itemId as text) =>
    let
        // Recursive function to fetch all pages
        FetchAllPages = (url as text, accumulatedData as list) =>
            let
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                versionData = jsonResponse[data],
                // Append the current page data to the accumulated data
                newAccumulatedData = List.Combine({accumulatedData, versionData}),
                // Check for the next page link
                nextLink = try jsonResponse[links][next][href] otherwise null,
                // If there is a next link, fetch the next page, otherwise return the accumulated data
                result = if nextLink <> null then @FetchAllPages("https://developer.api.autodesk.com" & nextLink, newAccumulatedData) else newAccumulatedData
            in
                result,

        // Initial URL
        initialUrl = "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/items/" & itemId & "/versions",
        // Fetch all pages
        allVersionData = FetchAllPages(initialUrl, {}),
        
        // Transform the accumulated data into a table
        details = Table.FromList(allVersionData, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        // Expand the columns
        expandedDetails = Table.ExpandRecordColumn(details, "Column1", {"id", "attributes", "relationships"}, {"File ID", "Attributes", "Relationships"}),

        //
        expandedAttributes = Table.ExpandRecordColumn(expandedDetails, "Attributes", {"name", "lastModifiedTime", "lastModifiedUserName", "versionNumber", "fileType"}, {"FileName", "LastModifiedAt", "LastModifiedBy", "VersionNumber", "FileType"}),
        expandedRelationship = Table.ExpandRecordColumn(expandedAttributes, "Relationships", {"storage"}, {"storage"}),
        expandedStorage = Table.ExpandRecordColumn(expandedRelationship, "storage", {"data"}, {"data"}),
        expandedMeta = Table.ExpandRecordColumn(expandedStorage, "data", {"id"}, {"Storage ID"}),

        // Extract bucket key and object key
        extractBucketKey = Table.AddColumn(expandedMeta, "BucketKey", each Text.Middle(Text.Split([Storage ID], ":"){3}, 0, Text.PositionOf(Text.Split([Storage ID], ":"){3}, "/"))),
        extractObjectKey = Table.AddColumn(extractBucketKey, "ObjectID", each Text.AfterDelimiter([Storage ID], "/"))

    in
        extractObjectKey;  

// Function to get file details
ACC_BIM360_Docs.SearchFile = (optional projectId as nullable text, optional folderId as nullable text, optional filter as nullable text, optional returnStyle as nullable text) =>
    let
         // Recursive function to fetch all pages of child folders and files
        FetchFiles = (projectId as text, folderId as text, nextPage as nullable text) =>
            let
                // Construct the URL for child folders and files
                url = if nextPage = null then "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/folders/" & folderId & "/search?" & filter else nextPage,
                // Fetch the data from the API
                source = Web.Contents(url),
                // Parse the JSON response
                jsonResponse = Json.Document(source),
                // Extract the data array
                data = jsonResponse[data],
                // Extract the next page URL
                nextPageUrl = try jsonResponse[links][next][href] otherwise null,
                // Fetch the next page if it exists
                nextPageData = if nextPageUrl <> null then @FetchFiles(projectId, folderId, nextPageUrl) else {},
                // Combine the current page data with the next page data
                combinedData = List.Combine({data, nextPageData})
            in
                combinedData,

        allFiles = FetchFiles(projectId, folderId, null),   
        filesTable = if allFiles = null then null else Table.FromList(allFiles, Splitter.SplitByNothing(), {"Record"}),

        UnfoldData = (filesTable as table) =>
            let 
                // Expand the attributes and relationships columns
                expandedFilesTable = if filesTable = null then null else Table.ExpandRecordColumn(filesTable, "Record", {"attributes", "relationships"}, {"attributes", "relationships"}),
                expandedAttributesTable = if expandedFilesTable = null then null else Table.ExpandRecordColumn(expandedFilesTable, "attributes", {"name", "createTime", "createUserName", "lastModifiedTime", "lastModifiedUserName", "versionNumber", "fileType"}, {"Name", "CreateTime", "CreateUserName", "LastModifiedTime", "LastModifiedUserName", "VersionNumber", "FileType"}),
                expandedRelationshipsTable = if expandedAttributesTable = null then null else Table.ExpandRecordColumn(expandedAttributesTable, "relationships", {"item", "storage"}, {"item", "storage"}),

                // Expand the item and storage columns
                expandedItemTable = if expandedRelationshipsTable = null then null else Table.ExpandRecordColumn(expandedRelationshipsTable, "item", {"data"}, {"data"}),
                expandedItemDataTable = if expandedItemTable = null then null else Table.ExpandRecordColumn(expandedItemTable, "data", {"id"}, {"ItemID"}),
                expandedStorageTable = if expandedItemDataTable = null then null else Table.ExpandRecordColumn(expandedItemDataTable, "storage", {"data"}, {"data"}),
                expandedStorageDataTable = if expandedStorageTable = null then null else Table.ExpandRecordColumn(expandedStorageTable, "data", {"id"}, {"Storage ID"}),

                // Extract bucket key and object ID from Storage ID
                addBucketKey = Table.AddColumn(expandedStorageDataTable, "BucketKey", each Text.Middle(Text.Split([Storage ID], ":"){3}, 0, Text.PositionOf(Text.Split([Storage ID], ":"){3}, "/"))),
                addObjectId = Table.AddColumn(addBucketKey, "ObjectID", each Text.AfterDelimiter([Storage ID], "/")),

                // remove Storage ID column
                removeStorageId = Table.RemoveColumns(addObjectId, {"Storage ID"})
            in
                removeStorageId,
        
        output = 
            if returnStyle = "Table" 
            then UnfoldData(filesTable) 
            else if returnStyle = "Boolean"
            then if Table.IsEmpty(UnfoldData(filesTable)) then false else true
            else UnfoldData(filesTable)
    in
        output;

// Function to get file details
ACC_BIM360_Docs.OpenWebLink = (optional link as nullable text) =>
    let
        projectId = "b." & Text.BetweenDelimiters(link, "/", "?", 5, 0),
        fileId = Text.Replace(Text.BetweenDelimiters(link, "=", "&", 1, 0), "%3A", ":"),
        output = ACC_BIM360_Docs.FileDetails("Tip", projectId, fileId, null, null)
    in
        output; 

// Data Source Kind description
ACC_BIM360_Docs = [
    TestConnection = (dataSourcePath) => {"ACC_BIM360_Docs.Contents"},
    Authentication = [
        OAuth = [
            Label = "OAuth",
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
ACC_BIM360_Docs.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = ACC_BIM360_Docs.Icons,
    SourceTypeImage = ACC_BIM360_Docs.Icons
];

StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorization_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,
            response_type = "code",
            redirect_uri = redirect_uri,
            scope = "data:read data:search",
            state = state
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code]);

// Define the Refresh function
Refresh = (resourceUrl, refresh_token) => RefreshTokenMethod(refresh_token);    

TokenMethod = (code) =>
    let
        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = client_id,
                client_secret = client_secret,
                grant_type = "authorization_code",
                code = code,
                redirect_uri = redirect_uri
            ])),
            Headers = [#"Content-Type" = "application/x-www-form-urlencoded", #"Accept" = "application/json"]
        ]),
        jsonResponse = Json.Document(tokenResponse)
    in
        jsonResponse;

// Define the RefreshToken function
RefreshTokenMethod = (refresh_token) =>
    let
        token_uri = token_uri & "?" & Uri.BuildQueryString([
            refresh_token = refresh_token,
            grant_type = "refresh_token"
        ]),
        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = client_id,
                client_secret = client_secret,
                scope = "data:read data:search"
            ])),
            Headers = [#"Content-Type" = "application/x-www-form-urlencoded", #"Accept" = "application/json"]
        ]),
        jsonResponse = Json.Document(tokenResponse)
    in
        jsonResponse;

// Define Table.ToNavigationTable function
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

ACC_BIM360_Docs.Icons = [
    Icon16 = { Extension.Contents("ACC_BIM360_Docs16.png"), Extension.Contents("ACC_BIM360_Docs20.png"), Extension.Contents("ACC_BIM360_Docs24.png"), Extension.Contents("ACC_BIM360_Docs32.png") },
    Icon32 = { Extension.Contents("ACC_BIM360_Docs32.png"), Extension.Contents("ACC_BIM360_Docs40.png"), Extension.Contents("ACC_BIM360_Docs48.png"), Extension.Contents("ACC_BIM360_Docs64.png") }
];
