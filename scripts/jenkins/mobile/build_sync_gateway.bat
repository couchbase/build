@echo off
::          
::    run by jenkins jobs:
::          
::        build_sync_gateway_master_win-2008-x64
::        build_sync_gateway_master_win-2008-x86
::        build_sync_gateway_master_win-2012-x64
::          
::        build_sync_gateway_100_win-2008-x64
::        build_sync_gateway_100_win-2008-x86
::        build_sync_gateway_100_win-2012-x64
::          
::    with required paramters:
::   
::          branch_name      version   release    platform     Edition
::             
::    e.g.: master         0.0.0-0000   0.0.0    windows-x64   community
::          release/1.0.0  1.0.0-1234   1.0.0    windows-x86   enterprise
::          
set THIS_SCRIPT=%0

set  GITSPEC=%1
if "%GITSPEC%" == "" call :usage 99

set  VERSION=%2
if "%VERSION%" == "" call :usage 88

set  RELEASE=%3
if "%VERSION%" == "" call :usage 77

set  PLATFRM=%4
if "%PLATFRM%" == "" call :usage 66

set  EDITION=%5
if "%EDITION%" == "" call :usage 55

set PUT_CMD="s3cmd put -P"
set PKGSTORE="s3://packages.couchbase.com/builds/mobile/sync_gateway/%RELEASE%/%VERSION%"

set LAST_GOOD_PARAM=%SYNCGATE_VERSION_PARAM%
set GOOS=windows
set OS=windows
set EXEC=sync_gateway.exe

if x%PROCESSOR_ARCHITECTURE:64=% NEQ x%PROCESSOR_ARCHITECTURE% (
    set ARCH=amd64
    set GOARCH=amd64 
    )
if x%PROCESSOR_ARCHITECTURE:86=% NEQ x%PROCESSOR_ARCHITECTURE% (
    set ARCH=x86
    set GOARCH=386
    )
if "%GOARCH%" EQ "" call :usage 44

set GOPLAT=%GOOS%-%GOARCH%
set PLATFORM=%OS%-%ARCH%

set PKGR=package-win.rb
set PKGTYPE=exe

set PKG_NAME=couchbase-sync-gateway_%VERSION%_%ARCHP%.%PKGTYPE%

if %EDITION:community=%  NEQ %EDITION% (
     set NEW_PKG_NAME=couchbase-sync-gateway_%VERSION%_%ARCHP%-%EDITION%.%PKGTYPE%
     )
if %EDITION:enterprise=% NEQ %EDITION% (
     set NEW_PKG_NAME=%PKG_NAME%
     )

set GO_RELEASE=1.2
set GOROOT=c:\usr\local\go\%GO_RELEASE%

set PATH=%PATH%;%GOROOT%\bin 

set
echo ============================================== %DATE%

set LIC_DIR=%WORKSPACE%\build\license\sync_gateway
set SGW_DIR=%WORKSPACE%\sync_gateway
set BLD_DIR=%SGW_DIR%\build

PREFIXD=%BLD_DIR%\opt\couchbase-sync-gateway
PREFIX=\opt\couchbase-sync-gateway
PREFIXP=.\opt\couchbase-sync-gateway

if EXIST %PREFIXD% del /s/f/q %PREFIXD%
mkdir -p %PREFIXD%\bin\

cd %WORKSPACE%
echo ======== sync sync_gateway ===================

if NOT EXIST sync_gateway  git clone https://github.com/couchbase/sync_gateway.git
cd           sync_gateway
git checkout      %GITSPEC%
git pull  origin  %GITSPEC%
git submodule init
git submodule update
git show --stat

FOR /F "usebackq" %%i in (`git log --oneline --pretty="format:%H" -1`) do @set REPO_SHA=%%i

se t TEMPLATE_FILE="src/github.com/couchbaselabs/sync_gateway/rest/api.go"
del %TEMPLATE_FILE%.orig
del %TEMPLATE_FILE%.new

echo ======== insert build meta-data ==============

setlocal disabledelayedexpansion
for /r %%i in (%TEMPLATE_FILE%) do (
    set line_A=%%i
    setlocal enabledelayedexpansion
    set line_B=%line_A:@PRODUCT_VERSION@=%VERSION%
    set line_C=%line_B:@COMMIT_SHA@=%REPO_SHA%
    echo %line_C% >> %TEMPLATE_FILE%.new
    endlocal
    )
endlocal
move  %TEMPLATE_FILE%       %TEMPLATE_FILE%.orig
move  %TEMPLATE_FILE%.new   %TEMPLATE_FILE%

cd %SGW_DIR%
echo ======== build ===============================
del /s/f/q bin
echo ................. %PLAT_DIR%
DEST_DIR=%SGW_DIR%\bin\%PLAT_DIR%
mkdir -p %DEST_DIR%

set GOPATH=%SGW_DIR%;%SGW_DIR%\vendor
CGO_ENABLED=1 GOOS=%GOOS% GOARCH=%GOARCH% go build -v github.com\couchbaselabs\sync_gateway

if NOT EXIST %SGW_DIR%\%EXEC% (
    echo "############################# FAIL! no such file: %DEST_DIR%\%EXEC%"
    exit 1
    )
move   %SGW_DIR%\%EXEC% %DEST_DIR%
echo "..................................Success! Output is: %DEST_DIR%\%EXEC%"

echo ======== remove build meta-data ==============
move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

echo ======== test ================================
echo ................... running tests from test.sh
    cd src\github.com\couchbaselabs\sync_gateway
    go vet     ./...
    go test -i ./...
    go test    ./...

echo ======== package =============================
cp %DEST_DIR%\%EXEC%                 %PREFIXD%\bin\
cp %BLD_DIR%\README.txt              %PREFIXD%
echo %VERSION%                     > %PREFIXD%\VERSION.txt
cp %LIC_DIR%\LICENSE_%EDITION%.txt   %PREFIXD%\LICENSE.txt

echo %BLD_DIR%' => ' .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP%
cd   %BLD_DIR%   ;   .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP%

echo  ======= upload ==============================
cp %PREFIXD%\%PKG_NAME% %SGW_DIR%\%NEW_PKG_NAME%
cd                      %SGW_DIR%
md5sum %NEW_PKG_NAME% > %NEW_PKG_NAME%.md5
echo        ........................... uploading to %PKGSTORE%\%NEW_PKG_NAME%
%PUT_CMD%  %NEW_PKG_NAME%                            %PKGSTORE%\%NEW_PKG_NAME%
%PUT_CMD%  %NEW_PKG_NAME%.md5                        %PKGSTORE%\%NEW_PKG_NAME%.md5

echo ============================================== %DATE%

goto :EOF
::##########################



::############# usage
:usage
    set ERR_CODE=%1
    echo.
    echo "use:  %THIS_SCRIPT%   branch_name  version  platform  edition  [ OS ]  [ ARCH ]  [ DISTRO ]"
    echo.
    echo "exiting ERROR code: %ERR_CODE%"
    echo.
    exit %ERR_CODE%
    goto :EOF

::#############
