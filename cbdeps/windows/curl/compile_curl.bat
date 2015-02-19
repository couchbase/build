rem Parameters
set target_arch=%1

if "%target_arch%" == "AMD64" goto setup_amd64
if "%target_arch%" == "x86"   goto setup_x86

:setup_x86
echo Setting up Visual Studio environment for x86
call "C:\Program Files\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"       x86
set machine=x64
goto build_curl

:setup_amd64
echo Setting up Visual Studio environment for amd64
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" amd64
set machine=x64
goto build_curl

:build_curl
nmake /f Makefile.vc mode=dll MACHINE=%machine% DEBUG=no
