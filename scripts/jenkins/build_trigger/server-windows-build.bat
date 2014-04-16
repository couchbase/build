
rem Detect 32-bit or 64-bit OS
Set RegQry=HKLM\Hardware\Description\System\CentralProcessor\0
REG.exe Query %RegQry% > checkOS.txt
Find /i "x86" < CheckOS.txt > StringCheck.txt
If %ERRORLEVEL% == 0 (
    set target_platform=x86
) ELSE (
    set target_platform=amd64
)

if "%target_platform%" == "amd64" goto setup_amd64
if "%target_platform%" == "x86" goto setup_x86

:setup_x86
echo Setting up Visual Studio environment for x86
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" x86
goto repo_download

:setup_amd64
echo Setting up Visual Studio environment for amd64
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" amd64
goto repo_download

:repo_download
if not exist couchbase mkdir couchbase
cd couchbase
if not exist .\.repo (
    mkdir .\.repo
    cd .\.repo
    git clone git://github.com/trondn/git-repo repo
    cd ..
    repo init -u git://github.com/couchbase/manifest -m branch-master.xml
)
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
nmake

cd ..
if exist voltron goto package_win
git clone ssh://git@github.com/ceejatec/voltron.git

:package_win
cd voltron
ruby server-win.rb %SOURCE_ROOT%\install 5.10.4 "C:\Program Files\erl5.10.4" couchbase-server 3.0.0-666 enterprise

:eof
