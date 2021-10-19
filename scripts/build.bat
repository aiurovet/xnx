@echo off

setlocal EnableDelayedExpansion

set PRJ=xnx
set PKZ=app\%PRJ%-windows.zip
set EXE=bin\%PRJ%.exe

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

echo Running the build for Windows

if not exist out (
    echo Creating the output directory
    mkdir out
    if errorlevel 1 exit /B 1
)

echo Getting the latest version of the packages
call dart pub get
if errorlevel 1 exit /B 1

echo Compiling "%EXE%"
dart compile exe bin\main.dart -o "%EXE%"
if errorlevel 1 exit /B 1

echo Copying the executable to the output directory
xcopy /Q "%EXE%" out
if errorlevel 1 exit /B 1

echo Copying README to the output directory
xcopy /Q README.md out
if errorlevel 1 exit /B 1

echo Copying examples to the output directory
xcopy /I /Q /S examples out\examples
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
%EXE% -d scripts\mkicons !ARGS!
if errorlevel 1 exit /B 1

echo Creating and compressing the application package
"%EXE%" --move --zip out "%PKZ%"
if errorlevel 1 exit /B 1

dir "%PKZ%"

if %OPT_KEEP% equ 0 (
    echo Removing the output directory
    del /Q "%EXE%"
)

exit /B 0
