
set PRODUCT=%1
set VERSION=%2
set SHA_VERSION=%3
set EDITION=%4

setlocal enabledelayedexpansion

set OS=windows

echo %SHA_VERSION%

set REL_PKG_DIR=MinSizeRel
set DEBUG_PKG_DIR=Debug

for %%A in (Win32 Win64 ARM) do (
    set ARCH=%%A

    if "!ARCH!"=="ARM" (
        rem Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! Debug || goto :error
        call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%DEBUG_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-debug-arm.zip ARM DEBUG || goto :error
        rem MinSizeRel
        set TARGET=!ARCH!_MinSizeRel
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! MinSizeRel || goto :error
        call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%REL_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-arm.zip ARM RELEASE || goto :error
        goto :EOF
    ) else (
        rem Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! Debug || goto :error
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! Debug || goto :error
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\%PRODUCT%\%DEBUG_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-winstore-debug.zip STORE_Win32 DEBUG || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%DEBUG_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-debug.zip Win32 DEBUG || goto :error
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\%PRODUCT%\%DEBUG_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-winstore-debug.zip STORE_Win64 DEBUG || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%DEBUG_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-debug.zip Win64 DEBUG || goto :error
        )
        rem Flavor: MinSizeRel
        set TARGET=!ARCH!_MinSizeRel
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! MinSizeRel || goto :error
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! MinSizeRel || goto :error
        if "%EDITION%"=="enterprise" (
            call :unit-test %WORKSPACE%\build_!TARGET!\%PRODUCT%  !ARCH! || goto :error
        )
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\%PRODUCT%\%REL_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-winstore.zip STORE_Win32 RELEASE || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%REL_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32.zip Win32 RELEASE || goto :error
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\%PRODUCT%\%REL_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-winstore.zip STORE_Win64 RELEASE || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\%PRODUCT%\%REL_PKG_DIR% %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64.zip Win64 RELEASE || goto :error
        )
    )
)
goto :EOF

rem subroutine "pkg"
:pkg
echo Creating pkg - pkgdir:%1, pkgname:%2, arch:%3 flavor:%4
cd %1
set PKG_NAME=%2
if "%4" == "DEBUG" (
    set FLAVOR=DEBUG
    ) else (
        set FLAVOR=RELEASE
)
7za a -tzip -mx9 %WORKSPACE%\%PKG_NAME% LiteCore.dll LiteCore.lib LiteCore.pdb || goto :error
set PROP_FILE=%WORKSPACE%\publish_!ARCH!.prop
echo PRODUCT=%PRODUCT%  >> %PROP_FILE%
echo VERSION=%SHA_VERSION% >> %PROP_FILE%
echo %FLAVOR%_PKG_NAME_%3=!PKG_NAME! >> %PROP_FILE%
goto :EOF

rem subroutine "bld_store"
:bld_store
echo Building blddir:%1, arch:%2, flavor:%3
set CMAKE_COMMON_OPTIONS=-DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION="10.0" -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION="10.0.16299.0" -DEDITION=%EDITION%
set project_dir=couchbase-lite-core

mkdir %1
cd %1
if "%2"=="Win32" (
    set MS_ARCH_STORE=
) else (
    IF "%2" == "ARM" (
        set MS_ARCH_STORE= ARM
    ) else (
        set MS_ARCH_STORE= Win64
    )
)

"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 15 2017%MS_ARCH_STORE%" %CMAKE_COMMON_OPTIONS%  .. || goto :error
"C:\Program Files\CMake\bin\cmake.exe" --build . --config %3 --target LiteCore || goto :error
goto :EOF

rem subroutine "bld"
:bld
echo Building blddir:%1, arch:%2, flavor:%3
set project_dir=couchbase-lite-core

mkdir %1
cd %1
if "%2"=="Win32" (
    set MS_ARCH=
) else (
    IF "%2" == "ARM" (
       set MS_ARCH= ARM
    ) else (
       set MS_ARCH= Win64
    )
)
"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 15 2017%MS_ARCH%" -DEDITION=%EDITION% .. || goto :error
"C:\Program Files\CMake\bin\cmake.exe" --build . --config %3 || goto :error
goto :EOF

rem subroutine "unit-test"
:unit-test
echo "Testing testdir:%1, arch:%2"
mkdir C:\tmp
mkdir %1\C\tests\data
cd %1\C\tests\data
if not exist "%1\C\tests\data\geoblocks.json" (
    copy %WORKSPACE%\couchbase-lite-core\C\tests\data\geoblocks.json  %1\C\tests\data\geoblocks.json
)
if not exist "%1\C\tests\data\names_300000.json" (
    copy %WORKSPACE%\couchbase-lite-core\C\tests\data\names_300000.json  %1\C\tests\data\names_300000.json
)

set cpp_test_path=%1\LiteCore\tests\MinSizeRel
set c4_test_path=%1\C\tests\MinSizeRel

cd %cpp_test_path%
.\CppTests.exe -r list || exit /b 1

cd %c4_test_path%
.\C4Tests.exe -r list || exit /b 1
goto :EOF

:error
echo Failed with error %ERRORLEVEL%
exit /B %ERRORLEVEL%
