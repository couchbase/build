@echo off
::
::    run by Jenkins Windows build jobs:
::
::        sync_gateway_windows_builds
::
::    with required paramters:
::
::          branch_name   git_commit  version  build_number  Edition  platform
::
::    This script only supports branches 1.2.0 and older
::
::    e.g.: master         123456   0.0.0 0000   community    windows-x64
::          release/1.0.0  123456   1.1.0 1234   enterprise   windows-x64
::
set THIS_SCRIPT=%0

set  GITSPEC=%1
if "%GITSPEC%" == "" call :usage 99

set  REL_VER=%2
if "%REL_VER%" == "" call :usage 88

set  BLD_NUM=%3
if "%BLD_NUM%" == "" call :usage 77

set  EDITION=%4
if "%EDITION%" == "" call :usage 55

set  PLATFRM=%5
if "%PLATFRM%" == "" call :usage 44

:: Sample TEST_OPTIONS "-cpu 4 -race"
set  TEST_OPTIONS=%6
set  REPO_SHA=%7
set  GO_RELEASE=%8

if not defined GO_RELEASE (
    set GO_RELEASE=1.5.3
)

set VERSION=%REL_VER%-%BLD_NUM%
if "%GITSPEC%" == "0.0.0" (
    set LATESTBUILDS_SGW="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/%REL_VER%/%VERSION%"
else (
    set LATESTBUILDS_SGW="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/0.0.1/%GITSPEC%/%VERSION%"
)

for /f "tokens=1-2 delims=-" %%A in ("%PLATFRM%") do (
    set OS=%%A
    set PROC_ARCH=%%B
)

set GOOS=%OS%
set SGW_EXEC=sync_gateway.exe
set SGW_NAME=sync-gateway
set ACCEL_EXEC=sg_accel.exe
set ACCEL_NAME=sg-accel

if "%PROC_ARCH%" == "x64" (
    set ARCH=amd64
    set PARCH=x86_64
    set GOARCH=amd64
    set GOHOSTARCH=%GOARCH%
)
if "%PROC_ARCH%" == "x86" (
    set ARCH=x86
    set PARCH=x86
    set GOARCH=386
    set GOHOSTARCH=%GOARCH%
)

set ARCHP=%ARCH%

set GOPLAT=%GOOS%-%GOARCH%
set PLATFORM=%OS%-%ARCH%

set PKGR=package-win.rb
set PKGTYPE=exe

set PKG_NAME=setup_couchbase-sync-gateway_%VERSION%_%ARCHP%.%PKGTYPE%
set NEW_PKG_NAME=couchbase-sync-gateway-%EDITION%_%VERSION%_%PARCH%.%PKGTYPE%

set ACCEL_PKG_NAME=setup_couchbase-sg-accel_%VERSION%_%ARCHP%.%PKGTYPE%
set ACCEL_NEW_PKG_NAME=couchbase-sg-accel-%EDITION%_%VERSION%_%PARCH%.%PKGTYPE%

set GOROOT=c:\usr\local\go\%GO_RELEASE%\go
set PATH=%PATH%;%GOROOT%\bin\

set
echo ============================================== %DATE%

:: package-win is tightly coupled to Jenkins workspace.
:: Changes needed to support concurrent builds later
::set TARGET_DIR=%WORKSPACE%\%GITSPEC:/=\%\%EDITION%
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

:: master branch maps to "0.0.0" for backward compatibility with pre-existing jobs 
if "%GITSPEC%" == "0.0.0" (
    set BRANCH=master
) else (
    set BRANCH=%GITSPEC%
    git checkout %BRANCH%
)
if "%REPO_SHA%" == "None" (
    git pull origin %BRANCH%
) else (
    git checkout %REPO_SHA%
)
git submodule init
git submodule update
git show --stat

if NOT EXIST %STAGING%           mkdir %STAGING%
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
set    DEST_DIR=%SGW_DIR%\bin
mkdir %DEST_DIR%

set GOPATH=%SGW_DIR%;%SGW_DIR%\vendor
set CGO_ENABLED=1
echo GOOS=%GOOS% GOARCH=%GOARCH%

:: Clean up stale objects before switching GO version
if EXIST %SGW_DIR%\pkg           rmdir /s/q %SGW_DIR%\pkg

go build -v github.com\couchbase\sync_gateway

if NOT EXIST %SGW_DIR%\%SGW_EXEC% (
    echo "############################# Sync-Gateway FAIL! no such file: %SGW_DIR%\%SGW_EXEC%"
    exit 1
    )
move   %SGW_DIR%\%SGW_EXEC% %DEST_DIR%
echo "..................................Sync-Gateway Success! Output is: %DEST_DIR%\%SGW_EXEC%"

if "%GITSPEC%" == "0.0.0" GOTO build_sg_accel
if "%GITSPEC%" GEQ "1.2.0" GOTO build_sg_accel

GOTO skip_build_sg_accel

:build_sg_accel
    go build -v github.com\couchbase\sync_gateway\sg_accel

    if NOT EXIST %SGW_DIR%\%ACCEL_EXEC% (
        echo "############################# SG-ACCEL FAIL! no such file: %SGW_DIR%\%ACCEL_EXEC%"
        exit 1
    )
    move   %SGW_DIR%\%ACCEL_EXEC% %DEST_DIR%
    echo "..................................SG-ACCEL Success! Output is: %DEST_DIR%\%ACCEL_EXEC%"

:skip_build_sg_accel

echo ======== remove build meta-data ==============
move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

echo ======== test ================================
echo ................... running tests from test.sh
    cd src\github.com\couchbase\sync_gateway
    go vet     ./...
    go test -i ./...
    go test -cpu 4 -race ./...

echo ======== build service wrappers ==============

set ACCEL_SERVICED=%SGW_DIR%\service\sg-windows
set ACCEL_SERVICE=%ACCEL_SERVICED%\sg-accel-service.exe

if "%GITSPEC%" == "0.0.0" GOTO build_service_wrapper
if "%GITSPEC%" GEQ "1.2.0" GOTO build_service_wrapper

GOTO build_service_wrapper

:build_service_wrapper
    if EXIST %ACCEL_SERVICED%\build.cmd (
	cd %ACCEL_SERVICED%
	call build.cmd
	) else (
	echo "############################# WINDOWS SERVICE WRAPPER build FAIL! no such file: %ACCEL_SERVICED%\build.cmd"
    )

    if NOT EXIST %ACCEL_SERVICE% (
        echo "############################# SG-ACCEL-SERVICE FAIL! no such file: %ACCEL_SERVICE%"
        exit 1
    )

:skip_build_service_wrapper

:: Jenkins seems to have a bug in the way how the slave starts (ssh vs jnlp)
:: Starting via ssh caused an issue with parsing long strings with spaces.
:: Temporary disable TEST_OPTIONS until slave can be started in jnlp mode.
::if "%TEST_OPTIONS%" == "None" (
::    go test ./...
::) else (
::    go test %TEST_OPTIONS% ./...
::)

echo ======== sync-gateway package ==========================
echo ".................staging sgw files to %STAGING%"
copy  %DEST_DIR%\%SGW_EXEC%             %STAGING%\bin\
copy  %BLD_DIR%\README.txt              %STAGING%\README.txt
echo  %VERSION%                       > %STAGING%\VERSION.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.txt   %STAGING%\LICENSE.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.rtf   %STAGING%\LICENSE.rtf

xcopy /s %SGW_DIR%\examples             %STAGING%\examples
xcopy /s %SGW_DIR%\service              %STAGING%\service

unix2dos  %STAGING%\README.txt
unix2dos  %STAGING%\VERSION.txt
unix2dos  %STAGING%\LICENSE.txt

echo %BLD_DIR%' => ' .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP% %SGW_NAME%
cd   %BLD_DIR%
                     .\%PKGR% %PREFIX% %PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP% %SGW_NAME%

if %ERRORLEVEL% NEQ 0 (
    echo "############################# Sync-Gateway Installer warning!"
    )

echo  ======= prep sync-gateway upload ==============================
copy %STAGING%\%PKG_NAME% %SGW_DIR%\%NEW_PKG_NAME%

echo ======== sg-accel package step 1==========================
set ACCEL_PREFIX=\opt\couchbase-sg-accel
set ACCEL_PREFIXP=.\opt\couchbase-sg-accel
set ACCEL_STAGING=%BLD_DIR%\opt\couchbase-sg-accel

if "%GITSPEC%" == "0.0.0" GOTO package_sg_accel
if "%GITSPEC%" GEQ "1.2.0" GOTO package_sg_accel

GOTO skip_package_sg_accel

:package_sg_accel
    cd   %BLD_DIR%
    if EXIST %ACCEL_PREFIX%  del /s/f/q %ACCEL_PREFIX%
    if EXIST %ACCEL_STAGING% del /s/f/q %ACCEL_STAGING%

    mkdir %ACCEL_STAGING%
    xcopy /s %STAGING% %ACCEL_STAGING%

    echo ======== sg-accel package step 2==========================
    echo ".................staging sg-accel files to %ACCEL_STAGING%"
    del /q %ACCEL_STAGING%\%PKG_NAME%
    del /q %ACCEL_STAGING%\bin\%SGW_EXEC%
    copy %DEST_DIR%\%ACCEL_EXEC%                 %ACCEL_STAGING%\bin\

    echo %BLD_DIR%' => ' .\%PKGR% %ACCEL_PREFIX% %ACCEL_PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP% %ACCEL_NAME%
    .\%PKGR% %ACCEL_PREFIX% %ACCEL_PREFIXP% %VERSION% %REPO_SHA% %PLATFORM% %ARCHP% %ACCEL_NAME%

    if %ERRORLEVEL% NEQ 0 (
        echo "#############################  SG-ACCEL Installer warning!"
        )

    echo  ======= prep sg_accel upload ==============================
    copy %ACCEL_STAGING%\%ACCEL_PKG_NAME% %SGW_DIR%\%ACCEL_NEW_PKG_NAME%

:skip_package_sg_accel

::cd                        %SGW_DIR%
::md5sum  %NEW_PKG_NAME%  > %NEW_PKG_NAME%.md5
::md5sum  %ACCEL_NEW_PKG_NAME%  > %ACCEL_NEW_PKG_NAME%.md5
echo        ........................... uploading internally to %LATESTBUILDS_SGW%

echo ============================================== %DATE%

goto :EOF
::##########################


::############# usage
:usage
    set ERR_CODE=%1
    echo.
    echo "use:  %THIS_SCRIPT%   branch_name  rel_ver build_num  edition  platform  commit_sha [ GO_VERSION ]"
    echo.
    echo "exiting ERROR code: %ERR_CODE%"
    echo.
    exit %ERR_CODE%
    goto :EOF

::#############
