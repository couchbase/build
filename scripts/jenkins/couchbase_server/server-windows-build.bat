@echo on

set VERSION=%1
set BLD_NUM=%2

set MANIFEST_FILE=%3
set LICENSE=%4
set ARCHITECTURE=%5

if "%MANIFEST_SHA%=="" set MANIFEST_SHA=master
if "%MANIFEST_REPO%"=="" set MANIFEST_REPO=git://github.com/couchbase/manifest
if "%WORKSPACE%"=="" set WORKSPACE=%CD%

set
echo ============================================== %DATE%

if not exist couchbase mkdir couchbase
cd couchbase
repo init -u %MANIFEST_REPO% -b %MANIFEST_SHA% -m %MANIFEST_FILE% -g all,-grommit --reference=C:/reporef || goto error
repo sync || goto error
if not exist install mkdir install
repo manifest -r > install/manifest.txt

set target_arch=%ARCHITECTURE%
set source_root=%WORKSPACE%\couchbase
call %source_root%\tlm\win32\environment.bat


echo ==============================================
set
echo ======== build ===============================

rmdir /s /q godeps\pkg goproj\pkg goproj\bin

if "%LICENSE%" == "enterprise" (
   set BUILD_ENTERPRISE=True
) else (
   set BUILD_ENTERPRISE=False
)

cmake -E touch CMakeLists.txt

nmake BUILD_ENTERPRISE=%BUILD_ENTERPRISE% EXTRA_CMAKE_OPTIONS="-D PRODUCT_VERSION=%VERSION%-%BLD_NUM%-rel -D CMAKE_ERL_LIB_INSTALL_PREFIX=lib -D CMAKE_BUILD_TYPE=Release" || goto error

cd ..
echo ============================================== %DATE%
goto eof

:error
echo Failed with error %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:eof
