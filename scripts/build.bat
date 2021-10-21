@echo off

setlocal EnableDelayedExpansion

rem ****************************************************************************

set PRJ=xnx
set VER=0.1.0

rem ****************************************************************************

set EXE=bin\%PRJ%.exe
set OUT=out\xnx-%VER%
set PKZ=app\%PRJ%-%VER%-windows.zip

rem Select-String -Pattern "^[\s]*version\:[\s]*(.*)$" -Path .\pubspec.yaml | %{ $_.Matches[0].Groups[1].Value }

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

if exist "%OUT%" (
    echo Removing the output directory
    rmdir /Q /S "%OUT%"
)

echo Creating the "%OUT%"
mkdir "%OUT%"
if errorlevel 1 ex"%OUT%"

rem ****************************************************************************

echo Getting the latest version of the packages
call dart pub get
if errorlevel 1 exit /B 1

echo Compiling "%EXE%"
dart compile exe bin\main.dart -o "%EXE%"
if errorlevel 1 exit /B 1

echo Copying the executable to the output directory
xcopy /Q "%EXE%" "%OUT%"
if errorlevel 1 exit /B 1

echo Copying installation instructions to the output directory
xcopy /Q INSTALL.txt "%OUT%"
if errorlevel 1 exit /B 1

echo Copying README to the output directory
xcopy /Q README.md "%OUT%"
if errorlevel 1 exit /B 1

echo Copying examples to the output directory
xcopy /I /Q /S examples "%OUT%\examples"
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
"%EXE%" -d scripts\mkicons !ARGS!
if errorlevel 1 exit /B 1

echo Creating and compressing the application package
"%EXE%" --move --zip out "%PKZ%"
if errorlevel 1 exit /B 1

rem ****************************************************************************

dir "%PKZ%"

if exist out (
    echo Removing the output directory
    del /Q /S out
)

if %OPT_KEEP% equ 0 (
    echo Removing the binary
    del /Q "%EXE%"
)

rem ****************************************************************************

exit /B 0

rem ****************************************************************************
