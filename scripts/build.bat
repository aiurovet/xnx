@echo off

setlocal EnableDelayedExpansion

set PRJ=xnx
set OST=Windows
set ZIP=app\%PRJ%-windows.zip

%~d0
if errorlevel 1 exit /B 1

cd "%~dp0.."
if errorlevel 1 exit /B 1

set OPT_MOVE=1

:loop

if /I "%~1" == "/K" (
    set OPT_MOVE=0
) else (
    set ARGS=!ARGS! %1
)

shift
if "%~1" neq "" goto :loop

rem Reset errorlevel
ver > nul

if not exist out (
    mkdir out
    if errorlevel 1 exit /B 1
)

call dart pub get
if errorlevel 1 exit /B 1

dart compile exe "bin\main.dart" -o "out\%PRJ%.exe"
if errorlevel 1 exit /B 1

set OSTYPE=%OST%
call scripts\mkicons\mkicons !ARGS!
if errorlevel 1 exit /B 1

xcopy /I /Q /S examples out\examples
if errorlevel 1 exit /B 1

xcopy /Q README.md out
if errorlevel 1 exit /B 1

out\%PRJ% --zip out "%ZIP%"
if errorlevel 1 exit /B 1

if %OPT_MOVE% neq 0 (
    rmdir /Q /S out
)

exit /B 0
