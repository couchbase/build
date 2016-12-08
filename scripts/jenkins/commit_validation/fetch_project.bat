@REM Fetches a project by project name, path and Git ref
@REM This script is normally used in conjunction with allcommits.py
@REM for /f "tokens=1-3" %%i in ('allcommits.py <change-id>') do (
@REM     call fetch_project.bat %%i %%j %%k
@REM )

set PROJECT=%1
set PROJECT_PATH=%2
set REFSPEC=%3

@IF NOT DEFINED GERRIT_HOST (
    @echo "Error: Required environment variable 'GERRIT_HOST' not set."
    @exit /b 1
)

@IF NOT DEFINED GERRIT_PORT (
    @echo "Error: Required environment variable 'GERRIT_PORT' not set."
    @exit /b 2
)

@IF NOT DEFINED PROJECT (
    @echo "Error: Required environment variable 'PROJECT' not set."
    @exit /b 3
)

@IF NOT DEFINED PROJECT_PATH (
    @echo "Error: Required environment variable 'PROJECT_PATH' not set."
    @exit /b 4
)

@IF NOT DEFINED REFSPEC (
    @echo "Error: Required environment variable 'REFSPEC' not set."
    @exit /b 5
)

pushd %PROJECT_PATH% || exit /b
git reset --hard HEAD || exit /b
git fetch ssh://%GERRIT_HOST%:%GERRIT_PORT%/%PROJECT% %REFSPEC% || exit /b
git checkout FETCH_HEAD || exit /b
popd || exit /b
