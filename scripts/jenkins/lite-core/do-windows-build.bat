
setlocal enabledelayedexpansion

set OS=windows

for /f %%i in ('call git --git-dir %WORKSPACE%/couchbase-lite-core/.git rev-parse HEAD') do set SHA=%%i
echo %SHA%

for %%A in (Win32 Win64 ARM) do (
    set ARCH=%%A

    if "!ARCH!"=="ARM" (
        # Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! Debug
        call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-!SHA!-%OS%-debug-arm.zip *.dll *.pdb ARM DEBUG
        #RelWithDebInfo
        set TARGET=!ARCH!_RelWithDebInfo
        call :bld_store %WORKSPACE%\build_!TARGET! !ARCH! RelWithDebInfo
        call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-!SHA!-%OS%-arm.zip *.dll *.pdb ARM RELEASE
        goto :EOF
    ) else (
        # Flavor: Debug
        set TARGET=!ARCH!_Debug
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! Debug
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! Debug
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\Debug %PRODUCT%-%VERSION%-!SHA!-%OS%-win32-winstore-debug.zip *.dll *.pdb STORE_Win32 DEBUG
            call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-!SHA!-%OS%-win32-debug.zip *.dll *.pdb Win32 DEBUG
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\Debug %PRODUCT%-%VERSION%-!SHA!-%OS%-win64-winstore-debug.zip *.dll *.pdb STORE_Win64 DEBUG
            call :pkg %WORKSPACE%\build_!TARGET!\Debug %PRODUCT%-%VERSION%-!SHA!-%OS%-win64-debug.zip *.dll *.pdb Win64 DEBUG
        )
        # Flavor: RelWithDebInfo
        set TARGET=!ARCH!_RelWithDebInfo
        call :bld_store %WORKSPACE%\build_cmake_store_!TARGET! !ARCH! RelWithDebInfo
        call :bld %WORKSPACE%\build_!TARGET! !ARCH! RelWithDebInfo
        if "!ARCH!"=="Win32" (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-!SHA!-%OS%-win32-winstore.zip *.dll *.pdb STORE_Win32 RELEASE
            call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-!SHA!-%OS%-win32.zip *.dll *.pdb Win32 RELEASE
        ) else (
            call :pkg %WORKSPACE%\build_cmake_store_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-!SHA!-%OS%-win64-winstore.zip *.dll *.pdb STORE_Win64 RELEASE
            call :pkg %WORKSPACE%\build_!TARGET!\RelWithDebInfo %PRODUCT%-%VERSION%-!SHA!-%OS%-win64.zip *.dll *.pdb Win64 RELEASE
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
7za a -tzip -mx9 %WORKSPACE%\%PKG_NAME%  %3  %4
set PROP_FILE=%WORKSPACE%\publish_!ARCH!.prop
echo PRODUCT=%PRODUCT%  >> %PROP_FILE%
echo VERSION=%SHA% >> %PROP_FILE%
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
"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 14 2015%MS_ARCH_STORE%" %CMAKE_COMMON_OPTIONS%  ..\couchbase-lite-core
"C:\Program Files\CMake\bin\cmake.exe" --build . --config %3 --target LiteCore
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
"C:\Program Files\CMake\bin\cmake.exe" -G "Visual Studio 14 2015%MS_ARCH%" ..\couchbase-lite-core
"C:\Program Files\CMake\bin\cmake.exe" --build . --config %3
goto :EOF
