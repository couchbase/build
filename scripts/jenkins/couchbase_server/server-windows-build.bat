@echo on

rem Parameters

setlocal EnableDelayedExpansion

set VERSION=%1
set BLD_NUM=%2
set LICENSE=%3

set ARCHITECTURE=amd64

:: Remember where we started
set START_DIR=%CD%

:: In addition to the above arguments, this scripts expects
:: to be launched from the top level of a Server repo directory.
:: For convenience, if WORKSPACE isn't set (ie, not run by Jenkins),
:: compute it from the path to this script.
if "%WORKSPACE%" == "" (
    set "SCRIPT_PATH=%~dp0"
    call :normalizepath "!SCRIPT_PATH!..\..\..\.."
    set "REPOROOT=!RETVAL!"
) else (
    set "REPOROOT=%WORKSPACE%"
)
cd %REPOROOT%
set

if not exist install mkdir install
copy manifest.xml install

set target_arch=%ARCHITECTURE%
set source_root=%CD%

:: If "cl" is already on the PATH, we've already executed environment.bat;
:: don't repeat lest we constantly expand PATH
where cl >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    call %source_root%\tlm\win32\environment.bat
)

:: environment.bat disables echo; re-enable it.
@echo on

@echo ==============================================
set
@echo ======== build ===============================

:: Delete previous run go artifacts - the go compiler doesn't always
:: rebuild the right stuff. We could run 'nmake clean' here, but that
:: deletes the whole build directory too, which slows things down.
rmdir /s /q godeps\pkg goproj\pkg goproj\bin

if "%LICENSE%" == "enterprise" (
   set BUILD_ENTERPRISE=True
) else (
   set BUILD_ENTERPRISE=False
)

set MAKETYPE="Ninja"
:: Ninja requires that we explictly tell cmake to use cl (MSVC),
:: otherwise it will auto-select gcc (MinGW) if that is installed.
set EXTRA_CMAKE_OPTIONS=-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl %EXTRA_CMAKE_OPTIONS%

cmake -E touch CMakeLists.txt

mkdir build
pushd build

cmake -G %MAKETYPE% ^
      -D CMAKE_INSTALL_PREFIX="%source_root%\install" ^
      -D CMAKE_PREFIX_PATH=";%source_root%\install" ^
      -D PRODUCT_VERSION=%VERSION%-%BLD_NUM% ^
      -D BUILD_ENTERPRISE=%BUILD_ENTERPRISE% ^
      -D CB_DEVELOPER_BUILD=True ^
      -D CB_DOWNLOAD_JAVA=True ^
      -D CMAKE_BUILD_TYPE=RelWithDebInfo ^
      -D CMAKE_ERL_LIB_INSTALL_PREFIX=lib ^
      %EXTRA_CMAKE_OPTIONS% ^
      %source_root% || goto error

cmake --build . --target install || goto error

rem Standalone Tools package
cmake --build . --target tools-package || goto error
move couchbase-server-tools_%VERSION%-%BLD_NUM%-windows_amd64.zip %REPOROOT%
popd

rem Archive all Windows debug files for future reference.
if not "%JENKINS_HOME%" == "" (
    7za a -tzip -mx9 -ir^^!*.pdb couchbase-server-%LICENSE%_%VERSION%-%BLD_NUM%-windows_%ARCHITECTURE%-PDB.zip
)


rem Pre-clean all unnecessary files
ruby voltron\cleanup.rb %REPOROOT%\install

@echo ==================== package =================

rem Discover erts version
for /D %%f in (%REPOROOT%\install\erts-*) do (
    set ERTSDIR=%%~nxf
)
set ERTSVER=%ERTSDIR:~5%

cd voltron
ruby server-win2015.rb %REPOROOT%\install %ERTSVER% %VERSION% %BLD_NUM% %LICENSE% windows_msvc2015 || goto error

set "productname=Server"
cd wix-installer
call create-installer.bat %REPOROOT%\install %VERSION% %BLD_NUM% %LICENSE% "%productname%" || goto error

set filebit=%LICENSE%
move Server.msi %REPOROOT%\couchbase-server-%filebit%_%VERSION%-%BLD_NUM%-windows_amd64-unsigned.msi

goto eof

:normalizepath
set "RETVAL=%~f1"
exit /b

:error
set CODE=%ERRORLEVEL%
cd %START_DIR%
echo Failed with error %CODE%.
exit /b %CODE%

:eof
cd %START_DIR%
