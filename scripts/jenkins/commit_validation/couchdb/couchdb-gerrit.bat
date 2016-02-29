@REM script for doing CV on windows for couchdb project
@IF NOT DEFINED target_arch (
    set target_arch=amd64
    @echo Notice: environment variable 'target_arch' not set. Defaulting to 'amd64'.
)

SET CURDIR=%~dp0

@echo.
@echo ============================================
@echo ===    environment                       ===
@echo ============================================

set
@echo.
set source_root=%WORKSPACE%
call tlm\win32\environment
@echo on

@echo.
@echo ============================================
@echo ===    clean                             ===
@echo ============================================

@REM Windows build is serial and there is no ccache, hence very slow.
@REM To try to alleviate this, we *don't* perform a top-level clean, only for
@REM the project subdirectory and Go objects (as it's incremental build is a bit flaky).
@REM This should speed things up a little, but still
@REM ensures that the correct number of warnings are reported for this project.
pushd build\couchdb
nmake clean
popd
del /F/Q/S godeps\pkg goproj\pkg goproj\bin

@echo.
@echo ============================================
@echo ===    update %GERRIT_PROJECT%           ===
@echo ============================================
for /f "tokens=1-3" %%i in ('%CURDIR%..\alldependencies.py %GERRIT_PATCHSET_REVISION% %GERRIT_PROJECT% %GERRIT_REFSPEC%') do (
    call %CURDIR%..\fetch_project.bat %%i %%j %%k
)

@echo.
@echo ============================================
@echo ===               Build                  ===
@echo ============================================

nmake EXTRA_CMAKE_OPTIONS="" || goto :error

@echo.
@IF NOT DEFINED SKIP_UNIT_TESTS (
    pushd build\couchdb
    nmake check || goto :error
    popd

    cd testrunner
    python scripts/start_cluster_and_run_tests.py b/resources/dev-4-nodes-xdcr.ini conf/simple.conf || goto :error
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
