@echo on

rem Parameters

set VERSION=%1
set BLD_NUM=%2
set BUILD_NUMBER=%VERSION%-%BLD_NUM%

set VOLTRON_BRANCH=%3
set MANIFEST=%4
set LICENSE=%5
set ARCHITECTURE=%6

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
rem #### set PKGSTORE="s3://packages.northscale.com/latestbuilds/%VERSION%/"

set
echo ============================================== %DATE%

if "%ARCHITECTURE%" == "amd64" goto setup_amd64
if "%ARCHITECTURE%" == "x86"   goto setup_x86

:setup_x86
echo Setting up Visual Studio environment for x86
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" x86
goto repo_download

:setup_amd64
echo Setting up Visual Studio environment for amd64
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" amd64
goto repo_download

:repo_download
@echo on
if not exist couchbase mkdir couchbase
cd couchbase
repo init -u git://github.com/couchbase/manifest -m %MANIFEST% || goto error
repo sync --jobs=4 || goto error
if not exist install mkdir install
repo manifest -r > install/manifest.txt
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
if "%ARCHITECTURE%" == "amd64" set PATH=%PATH%;%SOURCE_ROOT%\install\x86\bin

echo ==============================================
set
echo ======== build ===============================

rem Delete previous run go artifacts - the go compiler doesn't always
rem rebuild the right stuff. We could run 'nmake clean' here, but that
rem deletes the whole build directory too, which slows things down.
rmdir /s /q godeps\pkg
rmdir /s /q goproj\pkg
rmdir /s /q goproj\bin

if "%LICENSE%" == "enterprise" (
   set BUILD_ENTERPRISE=True
) else (
   set BUILD_ENTERPRISE=False
)

nmake BUILD_ENTERPRISE=%BUILD_ENTERPRISE% EXTRA_CMAKE_OPTIONS="-D PRODUCT_VERSION=%BUILD_NUMBER%-%REL% -D CMAKE_ERL_LIB_INSTALL_PREFIX=lib -D CB_DOWNLOAD_DEPS=1 -D CB_DOWNLOAD_DEPS_ARCH=%ARCHITECTURE% -D CB_DOWNLOAD_DEPS_CACHE=\cbdepscache-%ARCHITECTURE% -D CMAKE_BUILD_TYPE=Release" || goto error

cd ..
echo ============================================== %DATE%
goto eof

:error
echo Failed with error %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:eof
