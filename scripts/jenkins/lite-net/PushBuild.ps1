<#
.SYNOPSIS
    A tool for pushing Couchbase Lite nuget packages to either Nuget or the internal Couchbase feed
.DESCRIPTION
    This tool will optionally download the nuget packages from S3, and then push them all to the specified
    nuget feed
.PARAMETER Version
    The version of the library to download from S3 (required unless Prerelease)
.PARAMETER AccessKey
    The AWS access key (required unless Prerelease)
.PARAMETER SecretKey
    The AWS secret key (required unless Prerelease)
.PARAMETER Prerelease
    If specified, the packages will be assumed to be already downloaded and ready for upload.
    They will be uploaded to the internal Couchbase feed
.PARAMETER NugetApiKey
    The API key for pushing to the Nuget feed (always required)
.PARAMETER DryRun
    Perform all steps except for the actual Nuget feed push
.EXAMPLE
    C:\PS> .\PushBuild.ps1 -Version 2.0.0 -AccessKey <key> -SecretKey <key> -NugetApiKey <key>
    Pushes the official 2.0.0 packages to nuget.org
.EXAMPLE
    C:\PS> .\PromoteBuild.ps1 -Prerelease -NugetApiKey <key>
    Pushes a developer build to the internal Couchbase feed
#>
[CmdletBinding(DefaultParameterSetName='set2')]
param(
    [Parameter(ParameterSetName='set2', Mandatory=$true, HelpMessage="The version to download from S3")][string]$Version,
    [Parameter(ParameterSetName='set2', Mandatory=$true, HelpMessage="The access key of the AWS credentials")][string]$AccessKey,
    [Parameter(ParameterSetName='set2', Mandatory=$true, HelpMessage="The secret key of the AWS credentials")][string]$SecretKey,
    [Parameter(ParameterSetName='set1')][switch]$Prerelease,
    [Parameter(ParameterSetName='set2', Mandatory=$true, HelpMessage="The API key for pushing to the Nuget feed")]
    [Parameter(ParameterSetName='set1', Mandatory=$true, HelpMessage="The API key for pushing to the Nuget feed")][string]$NugetApiKey,
    [Parameter(ParameterSetName='set2')][switch]$DryRun
)

  
if(-Not $Prerelease) {
    Write-Host "Prelease not specified, downloading packages from S3..."
    Read-S3Object -BucketName packages.couchbase.com -KeyPrefix releases/couchbase-lite-net/$Version -Folder . -AccessKey $AccessKey -SecretKey $SecretKey
    $NugetUrl = "https://api.nuget.org/v3/index.json"
} else {
    $NugetUrl = "http://172.23.121.218/nuget/Developer"
}

if(-Not $(Test-Path .\nuget.exe) -and -not $DryRun) {
    Invoke-WebRequest https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile nuget.exe
}

foreach($file in (Get-ChildItem $pwd -Filter *.nupkg)) {
    if($Prerelease) {
        $NugetUrl = "http://172.23.121.218/nuget/Developer"
    } else {
        $NugetUrl = "https://api.nuget.org/v3/index.json"
    }

    if($DryRun) {
        Write-Host "DryRun specified, skipping push for $file"
    } else {
        & .\nuget.exe push $file -ApiKey $NugetApiKey -Source $NugetUrl
    }
}
