@echo off

setlocal EnableDelayedExpansion

rem ****************************************************************************

set PRJ=xnx
set VER=0.1.0
set ARC=_x86_64
set DTL=A tool to eXpand templates aNd eXecute commands on those

rem ****************************************************************************

set EXE=bin\%PRJ%.exe
set APP=app\Windows
set PKG=%APP%\%PRJ%-%VER%%ARC%
set OUT=%PKG%

rem ****************************************************************************

%~d0
if errorlevel 1 exit /B 1

cd "%~dp0.."
if errorlevel 1 exit /B 1

set OPT_KEEP=0

:loop

if /I "%~1" == "/K" (
    set OPT_KEEP=1
) else (
    set ARGS=!ARGS! %1
)

shift
if "%~1" neq "" goto :loop

rem Reset errorlevel
ver > nul

rem ****************************************************************************

echo Running the build for Windows

if exist "%PKG%" (
    echo Discarding the packaging directory "%PKG%"
    rmdir /Q /S "%PKG%"
)

if not exist "%OUT%" (
    echo Creating the output directory "%OUT%"
    mkdir "%OUT%"
    if errorlevel 1 exit /B 1
)

rem ****************************************************************************

echo Getting the latest version of the packages
call dart pub get
if errorlevel 1 exit /B 1

echo Compiling "%EXE%"
dart compile exe bin\main.dart -o "%EXE%"
if errorlevel 1 exit /B 1

echo Copying the executable installation guide, readme, license and examples to the output directory
xcopy /I /Q "%EXE%" "%OUT%"
if errorlevel 1 exit /B 1
xcopy /I /Q *.txt "%OUT%"
if errorlevel 1 exit /B 1
xcopy /I /Q *.md "%OUT%"
if errorlevel 1 exit /B 1
xcopy /I /Q /S examples "%OUT%\examples"
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
"%EXE%" -d scripts\mkicons "%PRJ%" "..\..\%OUT%" !ARGS!
if errorlevel 1 exit /B 1

echo Compiling the setup package
iscc "scripts\pkg-windows.iss"
if errorlevel 1 exit /B 1

rem ****************************************************************************

echo Removing the output directory
rmdir /Q /S "%OUT%"

if %OPT_KEEP% equ 0 (
    echo Removing the binary
    del /Q "%EXE%"
)

rem ****************************************************************************

exit /B 0

rem ****************************************************************************
