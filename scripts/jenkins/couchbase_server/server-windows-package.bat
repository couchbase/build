rem Parameters

set VERSION=%1
set BLD_NUM=%2
set PRODUCT_VER=%VERSION%-%BLD_NUM%

set MANIFEST=%3
set LICENSE=%4
set PLAT_TYPE=%5
set SRC_DIR_PREFIX=%6

# This path is just ever so slightly too long for Windows to deal with.
# So, move the directory.
move couchbase\voltron v
cd v

:package_win
echo ======== package =============================
ruby server-win.rb %WORKSPACE%\couchbase\install 5.10.4.0.0.1 couchbase-server %PRODUCT_VER% %LICENSE% %PLAT_TYPE% %SRC_DIR_PREFIX%  || goto error

set PKG_SRC_DIR=%WORKSPACE%\v
set PKG_NAME=couchbase-server-%LICENSE%_%PRODUCT_VER%-%PLAT_TYPE%_amd64.exe

copy %PKG_SRC_DIR%\%PKG_NAME% %WORKSPACE%

echo ========== creating trigger.properties ==============
cd %WORKSPACE%
echo PLATFORM=windows> trigger.properties
echo INSTALLER_FILENAME=%PKG_NAME%>> trigger.properties
