@echo off
::
::    run by Jenkins Windows build jobs:
::
::        sync_windows_build.bat SGW-2.0.0+
::
::    with required paramters:
::
::          branch_name   git_commit  version  build_number  Edition  platform
::
::    e.g.: master         123456   0.0.0 0000   community    windows-x64
::          release/1.0.0  123456   1.1.0 1234   enterprise   windows-x64
::
set THIS_SCRIPT=%0

set  REL_VER=%1
if "%REL_VER%" == "" call :usage 22

set  BLD_NUM=%2
if "%BLD_NUM%" == "" call :usage 33

set  EDITION=%3
if "%EDITION%" == "" call :usage 44

set  PLATFRM=%4
if "%PLATFRM%" == "" call :usage 55

:: Sample TEST_OPTIONS "-cpu 4 -race"
set  TEST_OPTIONS=%5
set  REPO_SHA=%6
set  GO_RELEASE=%7
set  MINIFORGE_VERSION=%8

if not defined GO_RELEASE (
    set GO_RELEASE=1.9.2
)

set CBDEP_VERSION=1.1.2
set CBDEP_URL=http://packages.couchbase.com/cbdep/%CBDEP_VERSION%/cbdep-%CBDEP_VERSION%-windows.exe
powershell -command "& { (New-Object Net.WebClient).DownloadFile('%CBDEP_URL%', 'cbdep.exe') }" || goto Err

set CBDEPS_DIR=%HOMEDRIVE%%HOMEPATH%\cbdeps

if not exist %HOMEDRIVE%%HOMEPATH%\cbdeps\go%GO_VERSION%\ (
    %WORKSPACE%\cbdep.exe -a amd64 install golang %GO_RELEASE% -d %CBDEPS_DIR%
)

set GOROOT=%CBDEPS_DIR%\go%GO_VERSION%
set "PATH=%GOROOT%\bin;%PATH%"
echo %PATH%

if defined MINIFORGE_VERSION if not exist %CBDEPS_DIR%\miniforge3-%MINIFORGE_VERSION%\ (
    %WORKSPACE%\cbdep.exe install miniforge3 %MINIFORGE_VERSION% -d %CBDEPS_DIR%
    call conda install -y pyinstaller
)

set "PATH=%CBDEPS_DIR%\miniforge3-%MINIFORGE_VERSION%;%CBDEPS_DIR%\miniforge3-%MINIFORGE_VERSION%\condabin;%CBDEPS_DIR%\miniforge3-%MINIFORGE_VERSION%\Scripts;%PATH%"
echo %PATH%

set VERSION=%REL_VER%-%BLD_NUM%

for /f "tokens=1-2 delims=-" %%A in ("%PLATFRM%") do (
    set OS=%%A
    set PROC_ARCH=%%B
)

set "SG_PRODUCT_NAME=Couchbase Sync Gateway"

set GOOS=%OS%
set SGW_EXEC=sync_gateway.exe
set SGW_NAME=sync-gateway
set COLLECTINFO_NAME=sgcollect_info

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

set PKGTYPE=msi
set SGW_PKG_NAME=couchbase-sync-gateway-%EDITION%_%VERSION%_%PARCH%-unsigned.%PKGTYPE%

set
echo ============================================== %DATE%

:: package-win is tightly coupled to Jenkins workspace.
:: Changes needed to support concurrent builds later
set TARGET_DIR=%WORKSPACE%
set BIN_DIR=%TARGET_DIR%\godeps\bin
set LIC_DIR=%TARGET_DIR%\product-texts\mobile\sync_gateway\license

if NOT EXIST %TARGET_DIR% (
    echo FATAL: Missing source...
    exit
)
cd %TARGET_DIR%

:: older sgw manifest maps sgw repo to godeps\src\github.com\couchbase\sync_gateway
if EXIST %TARGET_DIR%\sync_gateway (
    set SGW_DIR=%TARGET_DIR%\sync_gateway
    set GO_MOD_BUILD=true
) else (
    set SGW_DIR=%TARGET_DIR%\godeps\src\github.com\couchbase\sync_gateway
    set GO_MOD_BUILD=false
)

set BLD_DIR=%SGW_DIR%\build

set SGW_INSTALL_DIR=%TARGET_DIR%\sgw_install

if EXIST %SGW_INSTALL_DIR% del /s/f/q %SGW_INSTALL_DIR%

echo ======== sync sync_gateway ===================

if NOT EXIST %SGW_INSTALL_DIR%           mkdir %SGW_INSTALL_DIR%
if NOT EXIST %SGW_INSTALL_DIR%\tools     mkdir %SGW_INSTALL_DIR%\tools
if NOT EXIST %SGW_INSTALL_DIR%\examples  mkdir %SGW_INSTALL_DIR%\examples

set  REPO_FILE=%WORKSPACE%\revision.bat
if EXIST %REPO_FILE% (
    del /f %REPO_FILE%
)
echo set REPO_SHA=%REPO_SHA% > %REPO_FILE%
call %REPO_FILE%

set  TEMPLATE_FILE="%SGW_DIR%\rest\api.go"
if EXIST "%SGW_DIR%\base\version.go"  set TEMPLATE_FILE="%SGW_DIR%\base\version.go"
if EXIST %TEMPLATE_FILE%.orig	del %TEMPLATE_FILE%.orig
if EXIST %TEMPLATE_FILE%.new	del %TEMPLATE_FILE%.new

set PRODUCT_NAME=%SG_PRODUCT_NAME%

echo ======== insert %PRODUCT_NAME% build meta-data ==============

setlocal disabledelayedexpansion
for /F "usebackq tokens=1* delims=]" %%I in (`type %TEMPLATE_FILE% ^| find /V /N ""`) do (
    if "%%J"=="" (echo.>> %TEMPLATE_FILE%.new) else (
    set LINEA=%%J
    setlocal enabledelayedexpansion
    set LINEB=!LINEA:@PRODUCT_NAME@=%PRODUCT_NAME%!
    set LINEC=!LINEB:@PRODUCT_VERSION@=%VERSION%!
    set LINED=!LINEC:@COMMIT_SHA@=%REPO_SHA%!
    echo !LINED!>> %TEMPLATE_FILE%.new
    endlocal )
    )
endlocal

dos2unix %TEMPLATE_FILE%.new
move     %TEMPLATE_FILE%       %TEMPLATE_FILE%.orig
move     %TEMPLATE_FILE%.new   %TEMPLATE_FILE%

echo ======== build %PRODUCT_NAME% ===============================
set    DEST_DIR=%SGW_DIR%\bin
if EXIST %DEST_DIR%     del /s/f/q %DEST_DIR%
mkdir %DEST_DIR%

:: Clean up stale objects before switching GO version
if EXIST %SGW_DIR%\pkg           rmdir /s/q %SGW_DIR%\pkg

if "%EDITION%" == "enterprise" (
    set "GO_EDITION_OPTION=-tags cb_sg_enterprise"
) else (
    set GO_EDITION_OPTION=
)

set CGO_ENABLED=1
set GOPATH=%cd%\godeps
echo GOOS=%GOOS% GOARCH=%GOARCH% GOPATH=%GOPATH%

if "%GO_MOD_BUILD%" == "false" (
    set GO111MODULE=off
)
set GOPROXY=http://goproxy.build.couchbase.com
set GOPRIVATE=github.com/couchbaselabs/go-fleecedelta
pushd %SGW_DIR%
go install %GO_EDITION_OPTION% .\...
popd

IF "%VERSION:~0,2%"=="2." (
    echo go install github.com\couchbase\ns_server\deps\gocode\src\gozip
    go install github.com\couchbase\ns_server\deps\gocode\src\gozip
)

if NOT EXIST %BIN_DIR%\%SGW_EXEC% (
    echo "############################# Sync-Gateway FAIL! no such file: %BIN_DIR%\%SGW_EXEC%"
    exit 1
)
move   %BIN_DIR%\%SGW_EXEC% %DEST_DIR%
echo "..................................Sync-Gateway Success! Output is: %DEST_DIR%\%SGW_EXEC%"

echo ======== remove build meta-data ==============
move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

echo ======== test ================================
echo ................... running unit tests
echo ................... test options: %TEST_OPTIONS%
pushd %SGW_DIR%
go test %TEST_OPTIONS:"=% .\...
popd

if %ERRORLEVEL% NEQ 0 (
    echo "########################### FAIL! Unit test results = %ERRORLEVEL%"
    exit 1
)

echo ======== build service wrappers ==============
set SG_SERVICED=%SGW_DIR%\service\sg-windows
set SG_SERVICE=%SG_SERVICED%\sg-windows.exe

GOTO build_service_wrapper

:build_service_wrapper
    cd %SG_SERVICED%
    if EXIST build.cmd (
        call build.cmd
    ) else (
        echo "############################# WINDOWS SERVICE WRAPPER build FAIL! no such file: %SG_SERVICED%\build.cmd"
        exit 1
    )

    if NOT EXIST %SG_SERVICE% (
        echo "############################# SG-SERVICE FAIL! no such file: %SG_SERVICE%"
        exit 1
    )

echo ======== build sgcollect_info ===============================
set COLLECTINFO_DIR=%SGW_DIR%\tools
set COLLECTINFO_DIST=%COLLECTINFO_DIR%\dist\%COLLECTINFO_NAME%.exe

set CWD=%cwd%
cd %COLLECTINFO_DIR%
pyinstaller --onefile %COLLECTINFO_NAME%
if EXIST %COLLECTINFO_DIST% (
    echo "..............................SGCOLLECT_INFO Success! Output is: %COLLECTINFO_DIST%"
) else (
    echo "############################# SGCOLLECT-INFO FAIL! no such file: %COLLECTINFO_DIST%"
    exit 1
)
cd %CWD%

echo ======== sync-gateway package ==========================
echo ".................staging sgw files to %SGW_INSTALL_DIR%"
copy  %DEST_DIR%\%SGW_EXEC%             %SGW_INSTALL_DIR%\sync_gateway.exe
copy  %COLLECTINFO_DIST%                %SGW_INSTALL_DIR%\tools\

IF "%VERSION:~0,2%"=="2." (
    copy  %BIN_DIR%\gozip.exe               %SGW_INSTALL_DIR%\tools\
)
IF exist %BLD_DIR%\notices.txt (
    copy  %BLD_DIR%\notices.txt              %SGW_INSTALL_DIR%\notices.txt
)
copy  %BLD_DIR%\README.txt              %SGW_INSTALL_DIR%\README.txt
echo  %VERSION%                       > %SGW_INSTALL_DIR%\VERSION.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.txt   %SGW_INSTALL_DIR%\LICENSE.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.rtf   %SGW_INSTALL_DIR%\LICENSE.rtf

xcopy /s %SGW_DIR%\examples                    %SGW_INSTALL_DIR%\examples
copy  %SGW_DIR%\examples\serviceconfig.json    %SGW_INSTALL_DIR%\serviceconfig.json

unix2dos  %SGW_INSTALL_DIR%\README.txt
unix2dos  %SGW_INSTALL_DIR%\VERSION.txt
unix2dos  %SGW_INSTALL_DIR%\LICENSE.txt
unix2dos  %SGW_INSTALL_DIR%\LICENSE.rtf

echo  ======= start wix install  ==============================
cd %BLD_DIR%\windows\wix_installer
set WIX_INSTALLER=create-installer.bat
echo "Staging to wix install dir:  .\%WIX_INSTALLER% %SGW_INSTALL_DIR% %REL_VER% %EDITION% "%SGW_NAME%" %SGW_DIR%\service\sg-windows "
call .\%WIX_INSTALLER% %SGW_INSTALL_DIR% %REL_VER% %EDITION% "%SGW_NAME%" %SGW_DIR%\service\sg-windows || goto :error

if %ERRORLEVEL% NEQ 0 (
    echo "############################# Sync-Gateway Installer warning!"
    )

echo  ======= prep sync-gateway msi package file: %WORKSPACE%\%SGW_PKG_NAME%  ========================
move %SGW_NAME%.msi %WORKSPACE%\%SGW_PKG_NAME%

echo ============================================== %DATE%

:error
@echo Previous command failed with error #%errorlevel%.
exit /b %errorlevel%

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
