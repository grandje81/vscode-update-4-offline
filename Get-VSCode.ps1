[String] $ScriptFullPath = $MyInvocation.MyCommand.Source
[String] $ScriptName = $MyInvocation.MyCommand
$rootDir = $ScriptFullPath.Remove(($ScriptFullPath).IndexOf($ScriptName),($ScriptName).Length)
Import-Module "$rootDir\Get-VSCodeAG.psm1"
$Paths = $env:Path.Split(";")
$version = ""
$todaysDate = Get-Date -Format "yyyy-MM-dd"
$applicationName="VSCODE"
$relDir = ""
$global:ProgressPreference = "SilentlyContinue"
function New-ReleaseDir(){
    param ( 
        $version
    )
    if (Test-Path -Path $rootDir\RELEASE) {
        if (Test-Path -Path $rootDir\RELEASE\$todaysDate) {
            if(Test-Path -Path $rootDir\RELEASE\$todaysDate\$applicationName) {
                if(Test-Path -Path $rootDir\RELEASE\$todaysDate\$applicationName\$version) {
                    $ReleaseDir = "$rootDir\RELEASE\$todaysDate\$applicationName\$version\"
                    return $ReleaseDir
                } else {
                    [void](New-Item -ItemType Directory -Path $rootDir\RELEASE\$todaysDate\$applicationName\$version)
                    New-ReleaseDir -Version $version
                }
            } else {
                [void](New-Item -ItemType Directory -Path $rootDir\RELEASE\$todaysDate\$applicationName)
                New-ReleaseDir -Version $version
            }
        } else {
            [void](New-Item -ItemType Directory -Path $rootDir\RELEASE\$todaysDate)
            New-ReleaseDir -Version $version
        }
    }
    return
}
Function Get-CurrentVersionOfVSCode() {
    param (
        $vsCodePath
    )
    for($x = 0; $x -lt $vsCodePath.Length; $x++) {
        if($vsCodePath[$x] -like "*VS*") {
            [String] $vsCodeRootPath = $vsCodePath[$x]
            $vsCodeAppPath  = $vsCodeRootPath.TrimEnd("\bin") + "\resources\app"
            $vsCodeAppPackageJson = ConvertFrom-Json (Get-Content -Path ($vsCodeAppPath + "\package.json") -Raw)
            $vsCodeVersion = $vsCodeAppPackageJson.version
        }
    }
    return $vsCodeVersion
}
Write-Host "**********************************"
Write-Host "*           MENU                 *"
Write-Host "* 1. Download VS Code Zip        *"
Write-Host "* 2. Download VS Code Server     *"
Write-Host "* 3. Download VS Code Extensions *"
Write-Host "* 4. Download All above          *"
Write-Host "*                                *"
Write-Host "**********************************"

$answer = Read-Host -Prompt "Enter Choice"


switch($answer) 
{
    { $answer -eq 1 } {
        if( $relDir -eq "") {
            $version = Get-CurrentVersionOfVSCode -vsCodePath $Paths
            $relDir = New-ReleaseDir -version $version
        }
        if(Test-Path -Path $rootDir\RELEASE\$todaysDate\$applicationName\$version) {
            # Start-Sleep -Seconds 1
            Get-VSCodeArchive -ReleaseDir $relDir
            New-VSCodePortable  -ReleaseDir $relDir
            Remove-Module Get-VSCodeAG
        }
    }
    { $answer -eq 2 } {
        if( $relDir -eq "") {
            $version = Get-CurrentVersionOfVSCode -vsCodePath $Paths
            $relDir = New-ReleaseDir -version $version
        }
        New-VSCodeServer -ReleaseDir $relDir
        Remove-Module Get-VSCodeAG
    }
    { $answer -eq 3 } {
        if( $relDir -eq "") {
            $version = Get-CurrentVersionOfVSCode -vsCodePath $Paths
            $relDir = New-ReleaseDir -version $version
        }
        $vsCodeExtensionPath = $env:USERPROFILE + "\.vscode\extensions"
        New-VSCodeExtensions -VSCodeExtension $vsCodeExtensionPath -ReleaseDir $relDir
        Remove-Module Get-VSCodeAG
    }
    { $answer -eq 4} {
        if($relDir -eq "") {
            $version = Get-CurrentVersionOfVSCode -vsCodePath $Paths
            $relDir = New-ReleaseDir -version $version
            
        }
        if(Test-Path -Path $rootDir\RELEASE\$todaysDate\$applicationName\$version) {
            Get-VSCodeArchive -ReleaseDir $relDir
            New-VSCodePortable  -ReleaseDir $relDir 6>> $rootDir\LogFile.txt

            New-VSCodeServer -ReleaseDir $relDir
            New-VSCodeExtensions -VSCodeExtension $vsCodeExtensionPath -ReleaseDir $relDir
            Remove-Module Get-VSCodeAG
        }
    }
}
$global:ProgressPreference = "Continue"