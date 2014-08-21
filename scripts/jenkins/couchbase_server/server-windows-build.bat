@echo on

rem Parameters

set RELEASE=%1
set BLD_NUM=%2
set BUILD_NUMBER=%RELEASE%-%BLD_NUM%

set VOLTRON_BRANCH=%3
set MANIFEST=%4
set LICENSE=%5

if "%MANIFEST:~0,3%" == "toy" (
    rem                       # strip off "toy-" from beginning and ".xml" from end:
    set OWNER=%MANIFEST:~4,-4%
    set MANIFEST=toy/%MANIFEST%
    set REL=toy
) else (
    set REL=rel
)
:production_manifest

rem #### set PUT_CMD=s3cmd --config=c:\Users\Administrator\s3cmd.ini put --no-progress
rem #### set CHK_CMD=s3cmd --config=c:\Users\Administrator\s3cmd.ini ls
rem #### set PKGSTORE="s3://packages.northscale.com/latestbuilds/%RELEASE%/"

rem Detect 32-bit or 64-bit OS
set RegQry=HKLM\Hardware\Description\System\CentralProcessor\0
REG.exe Query %RegQry% > checkOS.txt
find /i "x86" < CheckOS.txt > StringCheck.txt
if %ERRORLEVEL% == 0 (
    set target_platform=x86
) else (
    set target_platform=amd64
)

set
echo ============================================== %DATE%

if "%target_platform%" == "amd64" goto setup_amd64
if "%target_platform%" == "x86"   goto setup_x86

:setup_x86
echo Setting up Visual Studio environment for x86
call "C:\Program Files\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"       x86
goto repo_download

:setup_amd64
echo Setting up Visual Studio environment for amd64
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" amd64
goto repo_download

:repo_download
@echo on
if not exist couchbase mkdir couchbase
cd couchbase
repo init -u git://github.com/couchbase/manifest -m %MANIFEST%
repo sync --jobs=4
set SOURCE_ROOT=%CD%

rem Unfortunately we need to have all of the directories
rem we build dlls in in the path in order to run make
rem test in a module..

echo Setting compile environment for building Couchbase server
set OBJDIR=\build
set MODULEPATH=%SOURCE_ROOT%%OBJDIR%\platform
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\libvbucket
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\cbsasl
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\memcached
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\couchstore
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\libmemcached
set MODULEPATH=%MODULEPATH%;%SOURCE_ROOT%%OBJDIR%\sigar\build-src
set PATH=%MODULEPATH%;%PATH%;%SOURCE_ROOT%\install\bin
set OBJDIR=
SET MODULEPATH=
cd %SOURCE_ROOT%
if "%target_platform%" == "amd64" set PATH=%PATH%;%SOURCE_ROOT%\install\x86\bin

echo ==============================================
set
echo ======== build ===============================

rem Install third-party deps
if exist %SOURCE_ROOT%\install rmdir /s /q %SOURCE_ROOT%\install
mkdir %SOURCE_ROOT%\install
if exist %SOURCE_ROOT%\deps\Makefile goto maybe_build_deps

mkdir %SOURCE_ROOT%\deps
cd %SOURCE_ROOT%\deps
cmake -D CMAKE_INSTALL_PREFIX=%SOURCE_ROOT%\install -G "NMake Makefiles" c:\depot\win_%target_platform%
cd %SOURCE_ROOT%
goto build_deps

:maybe_build_deps
if not exist %SOURCE_ROOT%\install\v8-rev.txt goto build_deps
goto build_couchbase

:build_deps
cd %SOURCE_ROOT%\deps
nmake
cd %SOURCE_ROOT%

:build_couchbase
if "%LICENSE%" == "enterprise" (
   set BUILD_ENTERPRISE=True
) else (
   set BUILD_ENTERPRISE=False
)

nmake BUILD_ENTERPRISE=%BUILD_ENTERPRISE% EXTRA_CMAKE_OPTIONS="-D PRODUCT_VERSION=%BUILD_NUMBER%-%REL% -D CMAKE_ERL_LIB_INSTALL_PREFIX=lib -D CB_DOWNLOAD_DEPS=1 -D CMAKE_BUILD_TYPE=RelWithDebugInfo"

cd ..
if exist voltron goto voltron_exists
    git clone --branch %VOLTRON_BRANCH% git://10.1.1.210/voltron.git
:voltron_exists

cd voltron
git reset --hard
git clean -dfx
git fetch
git checkout    %VOLTRON_BRANCH%
git pull origin %VOLTRON_BRANCH%

:package_win
echo ======== package =============================
ruby server-win.rb %SOURCE_ROOT%\install 5.10.4 "C:\Program Files\erl5.10.4" couchbase_server %BUILD_NUMBER% %LICENSE% %target_platform%

set PKG_SRC_DIR=%WORKSPACE%\voltron\couchbase_server\%RELEASE%\%BLD_NUM%
set PKG_SRC_NAME=couchbase_server-%LICENSE%-windows-%target_platform%-%BUILD_NUMBER%.exe

if "%MANIFEST:~0,3%" == "toy" (
    set PKG_DEST_NAME=couchbase_server-%OWNER%-%LICENSE%-windows-%target_platform%-%BUILD_NUMBER%.exe
) else (
    set PKG_DEST_NAME=%PKG_SRC_NAME%
)
copy %PKG_SRC_DIR%\%PKG_SRC_NAME% %WORKSPACE%\%PKG_DEST_NAME%

rem #### echo ======== upload ==============================
rem #### :upload_to_s3
rem #### echo %PUT_CMD% %WORKSPACE%\%PKG_DEST_NAME% %PKGSTORE%/%PKG_DEST_NAME%
rem ####      %PUT_CMD% %WORKSPACE%\%PKG_DEST_NAME% %PKGSTORE%/%PKG_DEST_NAME%
rem #### 
rem #### echo %CHK_CMD% %PKGSTORE%/%PKG_DEST_NAME%
rem ####      %CHK_CMD% %PKGSTORE%/%PKG_DEST_NAME%

echo ============================================== %DATE%
:eof
