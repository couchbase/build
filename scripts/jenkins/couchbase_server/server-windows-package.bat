rem Parameters

set VERSION=%1
set BLD_NUM=%2
set BUILD_NUMBER=%VERSION%-%BLD_NUM%

set MANIFEST=%3
set LICENSE=%4
set ARCHITECTURE=%5
set SRC_DIR_PREFIX=%6

# This path is just ever so slightly too long for Windows to deal with.
# So, move the directory.
move couchbase\voltron v
cd v

:package_win
echo ======== package =============================
ruby server-win.rb %WORKSPACE%\couchbase\install 5.10.4.0.0.1 couchbase_server %BUILD_NUMBER% %LICENSE% %ARCHITECTURE% %SRC_DIR_PREFIX%  || goto error

set PKG_SRC_DIR=%WORKSPACE%\v\couchbase_server\%VERSION%\%BLD_NUM%
set PKG_SRC_NAME=couchbase_server-%LICENSE%-windows-%ARCHITECTURE%-%BUILD_NUMBER%.exe
set PKG_DEST_NAME=couchbase-server-%LICENSE%_%BUILD_NUMBER%-windows_%ARCHITECTURE%.exe

copy %PKG_SRC_DIR%\%PKG_SRC_NAME% %WORKSPACE%\%PKG_DEST_NAME%

echo ========== creating trigger.properties ==============
cd %WORKSPACE%
echo PLATFORM=windows> trigger.properties
echo INSTALLER_FILENAME=%PKG_DEST_NAME%>> trigger.properties
