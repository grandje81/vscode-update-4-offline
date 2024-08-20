using namespace System.Net.Http
using namespace System.Net.Security
using namespace System.Net.ServicePointManager
function Get-RedirectedUrl {
    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )

    # Add-Type -AssemblyName System.Net.Http, System.Net.ServicePointManager, System.Net.SecurityProtocolType
    # Write-Host "Get-RedirectedUrl"
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 1024 
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $handler = New-Object HttpClientHandler
    $handler.AllowAutoRedirect=$false

    $client = New-Object HttpClient($handler)
    # $response = ($client.GetStringAsync($URL).GetAwaiter().GetResult())
    # $URL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
    try {
        $response = $client.GetAsync($URL)
    } catch {
        Write-Host $_.Exception
        $StatusCode = $_.Exception.Response.StatusCode.value_
        Write-Host "Error:"+ $StatusCode
    }
    if($response.Result.ReasonPhrase -eq "Found") {
        return $response.Result.Headers.Location.OriginalString
    }
}
function New-DataFolder() {
    param(
        $Destination,
        $ReleaseDir,
        $DataFolderPath
    )
    $extensionsDir = $ReleaseDir+"extensions"
    # Write-Host $DataFolderPath
    if(Test-Path -Path $DataFolderPath) {
        if(Test-Path -Path $extensionsDir) {
            # $dataPath = $Destination+"data"
            # $extensionsDir = $ReleaseDir+"extensions"
            [void](Move-Item -Path $extensionsDir -Destination $DataFolderPath.ToString())
        } else {
            Write-Host "No extensions dir to copy"
        }
        $ProfileDataToCopy = $env:APPDATA+"\Code"
        Copy-Item -Recurse -Path $ProfileDataToCopy -Destination $DataFolderPath.ToString()
        $ProfileDataDirToRename = $DataFolderPath.ToString()+"\Code"
        $ProfileDataDirNewName = $DataFolderPath.ToString()+"\user-data"
        Move-Item -Path $ProfileDataDirToRename -Destination $ProfileDataDirNewName
    } else {
        [void](New-Item -ItemType Directory -Path $Destination  -Name "data")
    }
    $ProfileDataToCopy = $env:APPDATA+"\Code"
    $ProfileDataDirToRename = $DataFolderPath.ToString()+"\Code"
    $ProfileDataDirNewName = $DataFolderPath.ToString()+"\user-data"
    if(Test-Path -Path $ProfileDataToCopy) {
        if(Test-Path -Path $ProfileDataDirToRename) {
            Move-Item -Path $ProfileDataDirToRename -Destination $ProfileDataDirNewName
        } else {
            if(Test-Path -Path $ProfileDataDirNewName) {
                Write-Information -MessageData "Nothing to do, all VS Code Portable directories are correctly named"
                # Write-EventLog -LogName 'Windows PowerShell' -EntryType Information -Message "Nothing to do, all VS Code Portable directories are correctly named"
            } 
        }
    }
}
function New-VSCodePortable() {
    param(
        $ReleaseDir
    )
    # $ReleaseDir = "C:\Utveckling\PowerShell\Update-AG-VSCODE\RELEASE\2024-06-04\VSCODE\1.89.1\"
    foreach($item in (Get-ChildItem -Path $ReleaseDir)) {
        if($item.Mode -ne "d-----"){
            if($item.Name -like "*.zip" -and $item.Name -notlike "*server*") {
                # write-Host $item
                [string] $archive = $item
            }
        }    
    }
    $dirNameFromArchiveName = $archive.Remove($archive.LastIndexOf("."),4)
    $DestinationPath = ""
    $DestinationPath = $ReleaseDir+$dirNameFromArchiveName
    if(Test-Path -Path $DestinationPath) {
        # $NewDir = $ReleaseDir+$dirNameFromArchiveName
        Write-Host $DestinationPath
        $PathToArchive = $ReleaseDir+$archive
        [void](Remove-Item -Recurse $DestinationPath)
        [void](New-Item -ItemType Directory -Path $ReleaseDir -Name $dirNameFromArchiveName)
        Expand-Archive -Path $PathToArchive -DestinationPath $DestinationPath
    } else {
        # $NewDir = $ReleaseDir+$dirNameFromArchiveName
        $PathToArchive = $ReleaseDir+$archive
        [void](New-Item -ItemType Directory -Path $ReleaseDir -Name $dirNameFromArchiveName)
        Expand-Archive -Path $PathToArchive -DestinationPath $DestinationPath 
    }
    $dataFolder = $DestinationPath+"\data"
    New-DataFolder -DataFolderPath $dataFolder -Destination $DestinationPath -ReleaseDir $ReleaseDir
}
function Get-VSCodeArchive() {
    param(
        $ReleaseDir
        )
        # Write-Host "Get-VSCodeArchive"
    $files = @(
        @{
            Uri = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
            OutFile = "$ReleaseDir"
        },
        @{
            Uri = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
            OutFile = "$ReleaseDir"
        }
    )
    $jobs = @()
    foreach ($file in $files) {
        [string] $urlForFileName = $file.Uri
        $FileName = [System.IO.Path]::GetFileName((Get-RedirectedUrl -URL $urlForFileName))
        # Write-Host "...."
        # Write-Host $FileName
        # Write-Host "...."
        $FileName = $FileName.TrimStart(" ")
        $file.Outfile = $file.Outfile+$FileName
        
        $jobs += Start-ThreadJob -Name $file.OutFile -ScriptBlock {
            $params = $using:file
            try {
                $Response = Invoke-WebRequest @params -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
                $StatusCode = $Response.StatusCode
                
            } catch {
                Write-Host $_.Exception
                $StatusCode = $_.Exception.Response.StatusCode.value_
                Write-Host "Error:"+ $StatusCode
            } 
        }
    }
    Write-Host "Downloads started for VS Code Archive..."
    Wait-Job -Job $jobs

    foreach ($job in $jobs) {
        Receive-Job -Job $job
    }
}
function Get-VSCodeServer() {
    param(
        $ReleaseDir,
        # $Guid,
        $Win,
        $Linux
    )
    $files = @(
    @{
        Uri = "https://update.code.visualstudio.com/commit:$linux/server-linux-x64/stable"
        OutFile = $ReleaseDir+"vscode-linux-x64.tar.gz"
    }
    @{
        Uri = "https://update.code.visualstudio.com/commit:$win/server-win32-x64/stable"
        OutFile = $ReleaseDir+"vscode-server-win32-x64.zip"
    }
    )
    $jobs = @()
    foreach ($file in $files) {
        $jobs += Start-ThreadJob -Name $file.OutFile -ScriptBlock {
            $params = $using:file
            try {
                $Response = Invoke-WebRequest @params -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
                $StatusCode = $Response.StatusCode
                
            } catch {
                Write-Host $_.Exception
                $StatusCode = $_.Exception.Response.StatusCode.value_
                Write-Host "Error: $StatusCode"
            }
        }
    }
    Write-Host "Downloads started for VS Code Server specific files..."
    Wait-Job -Job $jobs
    foreach ($job in $jobs) {
        Receive-Job -Job $job
    }
}
function New-VSCodeServer() {
    param(
        $ReleaseDir
    )
    $arch_win = ConvertFrom-Json (Invoke-WebRequest -UseBasicParsing "https://update.code.visualstudio.com/api/commits/stable/win32-x64").content
    $arch_linux = ConvertFrom-Json (Invoke-WebRequest -UseBasicParsing "https://update.code.visualstudio.com/api/commits/stable/linux-x64").content
    Get-VSCodeServer -ReleaseDir $ReleaseDir -Win $arch_win[0] -Linux $arch_linux[0]
}
function Get-VSCodeExtensions() {
    param(
        $URLs
    )
    $jobs = @()
    foreach ($file in $URLs) {
        $jobs += Start-ThreadJob -Name $file.OutFile -ScriptBlock {
            $params = $using:file
            try {
                $Response = Invoke-WebRequest @params -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
                $StatusCode = $Response.StatusCode
                
            } catch {
                Write-Host $_.Exception
                $StatusCode = $_.Exception.Response.StatusCode.value_
                Write-Host "Error: $StatusCode"
                # Write-Host $params.OutFile $params.Uri
            }
        }
    }
    Write-Host "Downloads started for VS Code Extensions specific files..."
    Wait-Job -Job $jobs
    foreach ($job in $jobs) {
        Receive-Job -Job $job
    }
}
function New-VSCodeExtensions() {
    param(
        $VSCodeExtension,
        $ReleaseDir
    )
    if(Test-Path -Path $VSCodeExtension) {
        $vscodeExtensionList = ConvertFrom-Json (Get-Content -Path ($VSCodeExtension + "\extensions.json"))
        $files = @()
        For($y = 0; $y -lt $vscodeExtensionList.Length; $y++) {
            $version = $vscodeExtensionList[$y].version
            [String] $relativeLocation = ($vsCodeExtensionList[$y].relativeLocation)
            $publisher = $relativeLocation.Split(".")[0]
            $extensionName = ($vsCodeExtensionList[$y].identifier.id).Split(".",2)[1]
            if(Test-Path ($ReleaseDir+"extensions")){
                $ExtensionsDir = $ReleaseDir+"extensions"
            } else {
                [void](New-Item -ItemType Directory -Path ($ReleaseDir+"extensions"))
                $ExtensionsDir = $ReleaseDir+"extensions"
            }
            
            $fileName = ("$ExtensionsDir\$relativeLocation" +".vsix")
            $files += @{
                Uri = "https://$publisher.gallery.vsassets.io/_apis/public/gallery/publisher/$publisher/extension/$extensionName/$version/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
                OutFile = $fileName
            }
        }
        Get-VSCodeExtensions -URLs $files
        foreach($item in (Get-ChildItem -Path $ReleaseDir)) {
            if($item.Mode -ne "d-----"){
                if($item.Name -like "*.zip" -and $item.Name -notlike "*server*") {
                    # write-Host $item
                    [string] $archive = $item
                }
            }    
        }
        $dirNameFromArchiveName = $archive.Remove($archive.LastIndexOf("."),4)
        $DestinationPath = ""
        $DestinationPath = $ReleaseDir+$dirNameFromArchiveName

        $dataFolder = $DestinationPath+"\data"
        New-DataFolder -DataFolderPath $dataFolder -Destination $DestinationPath -ReleaseDir $ReleaseDir
    }
}