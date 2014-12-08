@REM Common script run by various Jenkins commit-validation builds.

@REM Checks out the changeset specified by (GERRIT_PROJECT,GERRIT_REFSPEC) from
@REM Gerrit server GERRIT_HOST:GERRIT_PORT, compiles and then runs unit tests
@REM for GERRIT_PROJECT (if applicable).
@REM
@REM Triggered on patchset creation in a project's repo.

@IF NOT DEFINED GERRIT_HOST (
    @echo "Error: Required environment variable 'GERRIT_HOST' not set."
    @exit /b
)

@IF NOT DEFINED GERRIT_PORT (
    @echo "Error: Required environment variable 'GERRIT_PORT' not set."
    @exit /b
)

@IF NOT DEFINED GERRIT_PROJECT (
    @echo "Error: Required environment variable 'GERRIT_PROJECT' not set."
    @exit /b
)

@IF NOT DEFINED GERRIT_REFSPEC (
    @echo "Error: Required environment variable 'GERRIT_REFSPEC' not set."
    @exit /b
)
@IF NOT DEFINED target_platform (
    @echo "Error: Required environment variable 'target_platform' not set."
    @exit /b
)

@REM How many jobs to run in parallel by default?
@IF NOT DEFINED PARALLELISM (
    set PARALLELISM=8
)

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
@REM the project subdirectory. This should speed things up a little, but still
@REM ensures that the correct number of warnings are reported for this project.
pushd build\%GERRIT_PROJECT%
nmake clean
popd

@echo.
@echo ============================================
@echo ===    update %GERRIT_PROJECT%           ===
@echo ============================================

pushd %GERRIT_PROJECT%
git fetch ssh://%GERRIT_HOST%:%GERRIT_PORT%/%GERRIT_PROJECT% %GERRIT_REFSPEC%
git checkout FETCH_HEAD
popd

@echo.
@echo ============================================
@echo ===               Build                  ===
@echo ============================================

nmake EXTRA_CMAKE_OPTIONS="-DCB_DOWNLOAD_DEPS_ARCH=%target_platform%"

@echo.
@IF NOT DEFINED SKIP_UNIT_TESTS (
    @IF EXIST build\%GERRIT_PROJECT%\Makefile (
        @echo ============================================
        @echo ===          Run unit tests              ===
        @echo ============================================

        pushd build\%GERRIT_PROJECT%
        @REM  -j%PARALLELISM% : Run tests in parallel.
        @REM  -T Test   : Generate XML output file of test results.
        nmake test ARGS="-j%PARALLELISM% --output-on-failure --no-compress-output -T Test"
        popd
    ) ELSE (
        @echo ============================================
        @echo ===    No ${GERRIT_PROJECT} Makefile - skipping unit tests
        @echo ============================================
    )
) ELSE (
    @echo ============================================
    @echo ===    SKIP_UNIT_TESTS set - skipping unit tests
    @echo ============================================
)
