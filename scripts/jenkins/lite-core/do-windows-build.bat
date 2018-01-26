
PRODUCT=%1
VERSION=%2
SHA_VERSION=%3

setlocal enabledelayedexpansion

set OS=windows

echo %SHA_VERSION%

for %%A in (Win32 Win64 ARM) do (
    set ARCH=%%A

    if "!ARCH!"=="ARM" (
        # Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! Debug || goto :error
        call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-debug-arm.zip *.dll *.pdb ARM DEBUG || goto :error
        #RelWithDebInfo
        set TARGET=!ARCH!_RelWithDebInfo
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! RelWithDebInfo || goto :error
        call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-arm.zip *.dll *.pdb ARM RELEASE || goto :error
        goto :EOF
    ) else (
        # Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! Debug || goto :error
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! Debug || goto :error
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\Debug %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-winstore-debug.zip *.dll *.pdb STORE_Win32 DEBUG || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-debug.zip *.dll *.pdb Win32 DEBUG || goto :error
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\Debug %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-winstore-debug.zip *.dll *.pdb STORE_Win64 DEBUG || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-debug.zip *.dll *.pdb Win64 DEBUG || goto :error
        )
        # Flavor: RelWithDebInfo
        set TARGET=!ARCH!_RelWithDebInfo
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! RelWithDebInfo || goto :error
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! RelWithDebInfo || goto :error
        call :unit-test %WORKSPACE%\build_!TARGET!  !ARCH! || goto :error
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32-winstore.zip *.dll *.pdb STORE_Win32 RELEASE || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win32.zip *.dll *.pdb Win32 RELEASE || goto :error
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64-winstore.zip *.dll *.pdb STORE_Win64 RELEASE || goto :error
            call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-%SHA_VERSION%-%OS%-win64.zip *.dll *.pdb Win64 RELEASE || goto :error
        )
    )
)
goto :EOF

rem subroutine "pkg"
:pkg
echo Creating pkg - pkgdir:%1, pkgname:%2, dll:%3, pdb:%4, arch:%5 flavor:%6
cd %1
set PKG_NAME=%2
if "%6" == "DEBUG" (
    set FLAVOR=DEBUG
    ) else (
        set FLAVOR=RELEASE
)
7za a -tzip -mx9 %WORKSPACE%\%PKG_NAME%  %3  %4 || goto :error
set PROP_FILE=%WORKSPACE%\publish_!ARCH!.prop
echo PRODUCT=%PRODUCT%  >> %PROP_FILE%
echo VERSION=%SHA_VERSION% >> %PROP_FILE%
echo %FLAVOR%_PKG_NAME_%5=!PKG_NAME! >> %PROP_FILE%
goto :EOF

rem subroutine "bld_store"
:bld_store
echo Building blddir:%1, arch:%2, flavor:%3
set CMAKE_COMMON_OPTIONS=-DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION=10.0.14393.0 -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.10240.0
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
"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 14 2015%MS_ARCH_STORE%" %CMAKE_COMMON_OPTIONS%  ..\couchbase-lite-core || goto :error
"C:\Program Files\CMake\bin\cmake.exe" --build . --config %3 --target LiteCore || goto :error
goto :EOF

rem subroutine "bld"
:bld
echo Building blddir:%1, arch:%2, flavor:%3
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
"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 14 2015%MS_ARCH%" ..\couchbase-lite-core || goto :error
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

cd %1\LiteCore\tests\RelWithDebInfo
.\CppTests.exe -r list || exit /b 1

cd %1\C\tests\RelWithDebInfo
.\C4Tests.exe -r list || exit /b 1
goto :EOF

:error
echo Failed with error %ERRORLEVEL%
exit /B %ERRORLEVEL%
