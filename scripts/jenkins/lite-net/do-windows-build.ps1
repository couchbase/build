# couchbase-lite-net 2.0

# Defined required workspace environment
if (-not (Test-Path env:WORKSPACE)) { 
    $env:WORKSPACE = '.\'
}

# Setup required path
New-Item -ItemType directory -Path $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x86\RelWithDebInfo
New-Item -ItemType directory -Path $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x64\RelWithDebInfo
New-Item -ItemType directory -Path $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x86_store\RelWithDebInfo
New-Item -ItemType directory -Path $env:WORKSPACE\vendor\couchbase-lite-core\build_cmake\x64_store\RelWithDebInfo
New-Item -ItemType directory -Path $env:WORKSPACE\vendor\couchbase-lite-core\build_cmake\arm\RelWithDebInfo

Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x86\RelWithDebInfo\*.*
Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x64\RelWithDebInfo\*.*
Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x86_store\RelWithDebInfo\*.*
Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\x64_store\RelWithDebInfo\*.*
Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\arm\RelWithDebInfo\*.*

Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\libLiteCore.dylib
Remove-Item -Force $env:WORKSPACE\couchbase-lite-net\vendor\couchbase-lite-core\build_cmake\libLiteCore.so

# Write couchbase-lite-net sha to a version file
$xml = [xml](get-content $env:WORKSPACE\manifest.xml)
$xml_net = $xml.manifest.project | where { $_.name -eq 'couchbase-lite-net' }
$xml_core = $xml.manifest.project | where { $_.name -eq 'couchbase-lite-core' }
$LITE_NET_SHA_FULL = $xml_net.revision
$LITE_CORE_SHA_FULL = $xml_core.revision
echo LITE_NET_SHA_FULL: $LITE_NET_SHA_FULL
echo LITE_CORE_SHA_FULL: $LITE_CORE_SHA_FULL
$LITE_NET_SHA = $LITE_NET_SHA_FULL.Substring(0,7)
echo LITE_NET_SHA: $LITE_NET_SHA
echo $LITE_NET_SHA | Out-File -FilePath $env:WORKSPACE\couchbase-lite-net\src\Couchbase.Lite\Properties\version -Encoding ASCII -Force

# Required env settings
$env:NEXUS_REPO = "http://172.23.113.202:8081/nexus/content/repositories/releases/com/couchbase/litecore/"
$env:NUGET_REPO = "http://mobile.nuget.couchbase.com/nuget/CI/"
$env:NoGitSha=$true
$env:SourceLinkUrl = "https://raw.githubusercontent.com/couchbase/couchbase-lite-net/{commit}/*"
$env:FSHARPINSTALLDIR="C:\Program Files (x86)\Microsoft SDKs\F#\4.1\Framework\v4.0\"
$env:APPDATA="C:\Users\Administrator\AppData\Local"
$env:LOCALAPPDATA="C:\Users\Administrator\AppData\Local"

echo NUGET_VERSION: $env:NUGET_VERSION
$sha = $LITE_CORE_SHA_FULL

# Fetch required nexus dependencies and build
cd $env:WORKSPACE\couchbase-lite-net\src
echo $sha | Out-File -FilePath build\sha -Encoding ASCII -Force -NoNewline
build\do_fetch_litecore.ps1 -Variants all -NexusRepo $env:NEXUS_REPO -Sha $sha
build\do_build.bat
if ($LASTEXITCODE -ne 0) {
    exit 1
}

# Package and upload to nuget
cd ..\packaging\nuget
.\do_package.bat
if ($LASTEXITCODE -ne 0) {
    exit 1
}
