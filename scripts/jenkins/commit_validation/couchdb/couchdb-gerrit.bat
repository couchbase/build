@REM Script for doing CV on windows for couchdb project

SET SKIP_UNIT_TESTS=1
SET COUCHBASE_NUM_VBUCKETS=64
SET PATH=%WORKSPACE%\install\bin;%PATH%

SET CURDIR=%~dp0
call %CURDIR%..\single-project-gerrit.bat %*

@echo.
@echo ============================================
@echo ===          Install the build           ===
@echo ============================================
nmake || goto :error

@REM Enable unit tests (they'll also run dialyzer)
SET SKIP_UNIT_TESTS=

@echo.
@IF NOT DEFINED SKIP_UNIT_TESTS (
    @echo.
    @echo ============================================
    @echo ===     Run dialyzer and unit tests      ===
    @echo ============================================
    pushd build\couchdb
    nmake check || goto :error
    popd
) ELSE (
    @echo ============================================
    @echo ===    SKIP_UNIT_TESTS set - skipping unit tests
    @echo ============================================
)

:end
exit /b 0

:error
@echo Previous command failed with error #%errorlevel%.
exit /b %errorlevel%
