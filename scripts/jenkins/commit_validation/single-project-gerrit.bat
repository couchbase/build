@REM Common script run by various Jenkins commit-validation builds.

@REM Checks out the changeset specified by (GERRIT_PROJECT,GERRIT_REFSPEC) from
@REM Gerrit server GERRIT_HOST:GERRIT_PORT, compiles and then runs unit tests
@REM for GERRIT_PROJECT (if applicable).
@REM
@REM Triggered on patchset creation in a project's repo.

@IF NOT DEFINED GERRIT_HOST (
    @echo "Error: Required environment variable 'GERRIT_HOST' not set."
    @exit /b 1
)

@IF NOT DEFINED GERRIT_PORT (
    @echo "Error: Required environment variable 'GERRIT_PORT' not set."
    @exit /b 2
)

@IF NOT DEFINED GERRIT_PROJECT (
    @echo "Error: Required environment variable 'GERRIT_PROJECT' not set."
    @exit /b 3
)

@IF NOT DEFINED GERRIT_PATCHSET_REVISION (
    @echo "Error: Required environment variable 'GERRIT_PATCHSET_REVISION' not set."
    @exit /b 4
)
@IF NOT DEFINED GERRIT_REFSPEC (
    @echo "Error: Required environment variable 'GERRIT_REFSPEC' not set."
    @exit /b 5
)
@IF NOT DEFINED GERRIT_CHANGE_ID (
    @echo "Error: Required environment variable 'GERRIT_CHANGE_ID' not set."
    @exit /b 6
)
@IF NOT DEFINED target_arch (
    set target_arch=amd64
    @echo Notice: environment variable 'target_arch' not set. Defaulting to 'amd64'.
)

@REM How many jobs to run in parallel by default?
@IF NOT DEFINED PARALLELISM (
    set PARALLELISM=8
)
@IF NOT DEFINED TEST_PARALLELISM (
    set TEST_PARALLELISM=4
)

:: Set default CMake generator
@IF NOT DEFINED CMAKE_GENERATOR (
    set CMAKE_GENERATOR=NMake Makefiles
)

:: Ninja requires that we explictly tell cmake to use cl (MSVC),
:: otherwise it will auto-select gcc (MinGW) if that is installed.
IF "%CMAKE_GENERATOR%"=="Ninja" (
    set EXTRA_CMAKE_OPTIONS=%EXTRA_CMAKE_OPTIONS% -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl
)

@echo.
@echo ============================================
@echo ===    environment                       ===
@echo ============================================

set
@echo.
set "source_root=%WORKSPACE%"
call tlm\win32\environment
@echo on

@echo.
@echo ============================================
@echo ===    clean                             ===
@echo ============================================

:: The CMake / Go integration doesn't always correctly rebuild
:: modified source files on an incremental build. Therefore just
:: wipe out Go's binary directories (and essentially always
:: perform a clean build Go code).
del /F/Q/S godeps\pkg goproj\pkg goproj\bin

@echo.
@echo ============================================
@echo ===       update all projects with       ===
@echo ===          the same Change-Id          ===
@echo ============================================

SET "CURDIR=%~dp0"
python "%CURDIR%\checkout_dependencies.py" %GERRIT_PATCHSET_REVISION% %GERRIT_CHANGE_ID% %GERRIT_PROJECT% %GERRIT_REFSPEC% || goto :error

@echo.
@echo ============================================
@echo ===               Build                  ===
@echo ============================================

:: If we've checked out a specific version of the TLM
:: then we'll need to bring our new CMakeLists.txt in manually
del /f "CMakeLists.txt"
copy "tlm\CMakeLists.txt" "CMakeLists.txt"

if not exist build mkdir build
pushd build
cmake -G "%CMAKE_GENERATOR%" %CMAKE_ARGS% %EXTRA_CMAKE_OPTIONS% .. || goto :error
cmake --build . --target install || goto :error
popd

@echo.
@IF NOT DEFINED SKIP_UNIT_TESTS (
    @IF EXIST build\%GERRIT_PROJECT%\CTestTestfile.cmake (
        @echo ============================================
        @echo ===          Run unit tests              ===
        @echo ============================================

        pushd build\%GERRIT_PROJECT%
        @REM  -j%PARALLELISM% : Run tests in parallel.
        @REM  -T Test   : Generate XML output file of test results.
        ctest -j%TEST_PARALLELISM% --output-on-failure --no-compress-output -T Test  --exclude-regex %TESTS_EXCLUDE%
        popd
    ) ELSE (
        @echo ============================================
        @echo ===    No %GERRIT_PROJECT% CTestTestfile.cmake - skipping unit tests
        @echo ============================================
    )
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
