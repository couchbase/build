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
if "%RELEASE%" == "" call :usage 77

set  PLATFRM=%4
if "%PLATFRM%" == "" call :usage 66

set  EDITION=%5
if "%EDITION%" == "" call :usage 55

set PUT_CMD=s3cmd --config=c:\Users\Administrator\s3cmd.ini put -P --no-progress
set CHK_CMD=s3cmd --config=c:\Users\Administrator\s3cmd.ini ls
set PKGSTORE="s3://packages.couchbase.com/builds/mobile/sync_gateway/%RELEASE%/%VERSION%"

set LAST_GOOD_PARAM=%SYNCGATE_VERSION_PARAM%
set GOOS=windows
set OS=windows
set EXEC=sync_gateway.exe

if NOT "%PROCESSOR_IDENTIFIER:64=%" == "%PROCESSOR_IDENTIFIER%" (
    set ARCH=amd64
    set GOARCH=amd64
    set GOHOSTARCH=%GOARCH%
    )
if NOT "%PROCESSOR_IDENTIFIER:86=%" == "%PROCESSOR_IDENTIFIER%" (
    set ARCH=x86
    set GOARCH=386
    set GOHOSTARCH=%GOARCH%
    )
if "%GOARCH%" == "" call :usage 44

set GOPLAT=%GOOS%-%GOARCH%
set PLATFORM=%OS%-%ARCH%

set PKGR=package-win.rb
set PKGTYPE=exe

set ARCHP=%ARCH%
set PARCH=%ARCHP%

if  "%ARCHP%" == "i386" (
    set PARCH=x86
    )
if "%ARCHP%" == "amd64" (
    set PARCH=x86_64
    )
set     PKG_NAME=setup_couchbase-sync-gateway_%VERSION%_%ARCHP%.%PKGTYPE%
set NEW_PKG_NAME=couchbase-sync-gateway-%EDITION%_%VERSION%_%PARCH%.%PKGTYPE%

set GO_RELEASE=1.2
set GOROOT=c:\usr\local\go\%GO_RELEASE%

set PATH=%PATH%;%GOROOT%\bin\

set
echo ============================================== %DATE%

set LIC_DIR=%WORKSPACE%\build\license\sync_gateway
set AUT_DIR=%WORKSPACE%\app-under-test
set SGW_DIR=%AUT_DIR%\sync_gateway
set BLD_DIR=%SGW_DIR%\build

set PREFIX=\opt\couchbase-sync-gateway
set PREFIXP=.\opt\couchbase-sync-gateway
set STAGING=%BLD_DIR%\opt\couchbase-sync-gateway

if EXIST %PREFIX%  del /s/f/q %PREFIX%
if EXIST %STAGING% del /s/f/q %STAGING%

if NOT EXIST %AUT_DIR%  mkdir %AUT_DIR%
cd           %AUT_DIR%
echo ======== sync sync_gateway ===================

if NOT EXIST sync_gateway  git clone https://github.com/couchbase/sync_gateway.git
cd           sync_gateway
git checkout      %GITSPEC%
git pull  origin  %GITSPEC%
git submodule init
git submodule update
git show --stat

if NOT EXIST %STAGING%\bin       mkdir %STAGING%\bin
if NOT EXIST %STAGING%\examples  mkdir %STAGING%\examples
if NOT EXIST %STAGING%\service   mkdir %STAGING%\service

set  REPO_FILE=%WORKSPACE%\revision.bat
git  log --oneline --pretty="format:set REPO_SHA=%%H" -1 > %REPO_FILE%
call %REPO_FILE%

set  TEMPLATE_FILE="src\github.com\couchbase\sync_gateway\rest\api.go"
del %TEMPLATE_FILE%.orig
del %TEMPLATE_FILE%.new

echo ======== insert build meta-data ==============

setlocal disabledelayedexpansion
for /F "usebackq tokens=1* delims=]" %%I in (`type %TEMPLATE_FILE% ^| find /V /N ""`) do (
    if "%%J"=="" (echo.>> %TEMPLATE_FILE%.new) else (
    set LINEA=%%J
    setlocal enabledelayedexpansion
    set LINEB=!LINEA:@PRODUCT_VERSION@=%VERSION%!
    set LINEC=!LINEB:@COMMIT_SHA@=%REPO_SHA%!
    echo !LINEC!>> %TEMPLATE_FILE%.new
    endlocal )
    )
endlocal

dos2unix %TEMPLATE_FILE%.new
move     %TEMPLATE_FILE%       %TEMPLATE_FILE%.orig
move     %TEMPLATE_FILE%.new   %TEMPLATE_FILE%

cd %SGW_DIR%
echo ======== build ===============================
del /s/f/q bin
echo ................. %PLAT_DIR%
set    DEST_DIR=%SGW_DIR%\bin\%PLAT_DIR%
mkdir %DEST_DIR%

set GOPATH=%SGW_DIR%;%SGW_DIR%\vendor
set CGO_ENABLED=1
echo GOOS=%GOOS% GOARCH=%GOARCH%
go build -v github.com\couchbase\sync_gateway

if NOT EXIST %SGW_DIR%\%EXEC% (
    echo "############################# FAIL! no such file: %SGW_DIR%\%EXEC%"
    exit 1
    )
move   %SGW_DIR%\%EXEC% %DEST_DIR%
echo "..................................Success! Output is: %DEST_DIR%\%EXEC%"

echo ======== remove build meta-data ==============
move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

echo ======== test ================================
echo ................... running tests from test.sh
    cd src\github.com\couchbase\sync_gateway
    go vet     ./...
    go test -i ./...
    go test    ./...

echo ======== package =============================
copy  %DEST_DIR%\%EXEC%                 %STAGING%\bin\
copy  %BLD_DIR%\README.txt              %STAGING%\README.txt
echo  %VERSION%                       > %STAGING%\VERSION.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.txt   %STAGING%\LICENSE.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.rtf   %STAGING%\LICENSE.rtf

xcopy /s %SGW_DIR%\examples             %STAGING%\examples
xcopy /s %SGW_DIR%\service              %STAGING%\service

unix2dos  %STAGING%\README.txt
unix2dos  %STAGING%\VERSION.txt
unix2dos  %STAGING%\LICENSE.txt

echo %BLD_DIR%' => ' .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP%
cd   %BLD_DIR%
                     .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP%

echo  ======= upload ==============================
copy %STAGING%\%PKG_NAME% %SGW_DIR%\%NEW_PKG_NAME%
cd                        %SGW_DIR%
md5sum  %NEW_PKG_NAME%  > %NEW_PKG_NAME%.md5
echo        ........................... uploading to %PKGSTORE%/%NEW_PKG_NAME%
%PUT_CMD%  %NEW_PKG_NAME%                            %PKGSTORE%/%NEW_PKG_NAME%
%CHK_CMD%                                            %PKGSTORE%/%NEW_PKG_NAME%
%PUT_CMD%  %NEW_PKG_NAME%.md5                        %PKGSTORE%/%NEW_PKG_NAME%.md5
%CHK_CMD%                                            %PKGSTORE%/%NEW_PKG_NAME%.md5

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
