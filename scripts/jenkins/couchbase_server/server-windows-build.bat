@echo on

rem Parameters

set VERSION=%1
set BLD_NUM=%2

set MANIFEST_FILE=%3
set LICENSE=%4
set ARCHITECTURE=%5

rem In addition to the above arguments, this scripts expects
rem to be launched from the top level of a sherlock repo directory.
set
echo ======== %DATE% =============================

if not exist install mkdir install
repo manifest -r > install/manifest.txt

set target_arch=%ARCHITECTURE%
set source_root=%CD%
call %source_root%\tlm\win32\environment.bat

echo ==============================================
set
echo ======== build ===============================

rem Delete previous run go artifacts - the go compiler doesn't always
rem rebuild the right stuff. We could run 'nmake clean' here, but that
rem deletes the whole build directory too, which slows things down.
rmdir /s /q godeps\pkg goproj\pkg goproj\bin

if "%LICENSE%" == "enterprise" (
   set BUILD_ENTERPRISE=True
) else (
   set BUILD_ENTERPRISE=False
)

set MAKETYPE="Ninja"
rem Ninja requires that we explictly tell cmake to use cl (MSVC),
rem otherwise it will auto-select gcc (MinGW) if that is installed.
set EXTRA_CMAKE_OPTIONS=-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl

cmake -E touch CMakeLists.txt

mkdir build
pushd build

cmake -G %MAKETYPE% ^
      -D CMAKE_INSTALL_PREFIX="%source_root%\install" ^
      -D CMAKE_PREFIX_PATH=";%source_root%\install" ^
      -D PRODUCT_VERSION=%VERSION%-%BLD_NUM% ^
      -D BUILD_ENTERPRISE=%BUILD_ENTERPRISE% ^
      -D CMAKE_BUILD_TYPE=RelWithDebInfo ^
      -D CMAKE_ERL_LIB_INSTALL_PREFIX=lib ^
      %EXTRA_CMAKE_OPTIONS% ^
      %source_root% || goto error

cmake --build . || goto error
popd

rem Archive all Windows debug files for future reference.
7za a -tzip -mx9 -ir!*.pdb couchbase-server-%LICENSE%_%VERSION%-%BLD_NUM%-windows_%ARCHITECTURE%-PDB.zip

rem Pre-clean all unnecessary files
ruby voltron\cleanup.rb %WORKSPACE%\couchbase\install

echo ============================================== %DATE%
goto eof

:error
echo Failed with error %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:eof
