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

@IF NOT DEFINED GERRIT_SCHEME (
    @echo "Error: Required environment variable 'GERRIT_SCHEME' not set."
    @exit /b 3
)

@IF NOT DEFINED PROJECT (
    @echo "Error: Required argument 'PROJECT' not set."
    @exit /b 4
)

@IF NOT DEFINED PROJECT_PATH (
    @echo "Error: Required argument 'PROJECT_PATH' not set."
    @exit /b 5
)

@IF NOT DEFINED REFSPEC (
    @echo "Error: Required argument 'REFSPEC' not set."
    @exit /b 6
)

@if not exist %PROJECT_PATH% (
    @echo "%PROJECT_PATH% doesn't exist, skipping..."
    @exit /b 0
)

pushd %PROJECT_PATH% || exit /b 1
git reset --hard HEAD || exit /b 1
git fetch %GERRIT_SCHEME%://%GERRIT_HOST%:%GERRIT_PORT%/%PROJECT% %REFSPEC% || exit /b 1
git clean -d --force -x || exit /b 1
git checkout FETCH_HEAD || exit /b 1
popd || exit /b 1
