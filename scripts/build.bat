@echo off

setlocal EnableDelayedExpansion

set PRJ=xnx
set APP=app
set BIN=bin
set OST=Windows
set OST_LC=windows

set ZIP=%APP%\%PRJ%-%OST_LC%.zip
set BIN_OST=%BIN%\%OST%\%PRJ%

set OPT_MOVE=1

:loop

if "%~1" == "-k" (
    set OPT_MOVE=0
) else (
    set ARGS=!ARGS! %1
)

shift
if "%~1" neq "" goto :loop

rem Reset errorlevel
ver > nul

%~d0
if errorlevel 1 exit /B 1

cd %~dp0
if errorlevel 1 exit /B 1

if not exist "%BIN_OST%" (
    mkdir "%BIN_OST%"
    if errorlevel 1 exit /B 1
)

call dart pub get
if errorlevel 1 exit /B 1

dart compile exe "%BIN%\main.dart" -o "%BIN_OST%\%PRJ%.exe"
if errorlevel 1 exit /B 1

set OSTYPE=%OST%
call scripts\mkicons\mkicons !ARGS!
if errorlevel 1 exit /B 1

xcopy /Q /S examples "%BIN_OST%"
if errorlevel 1 exit /B 1

xcopy /Q "README.md" "%BIN_OST%"
if errorlevel 1 exit /B 1

"%BIN_OST%\%PRJ%" --zip "%BIN_OST%" "%ZIP%"
if errorlevel 1 exit /B 1

if %OPT_MOVE% neq 0 (
    rmdir /Q /S "%BIN%\%OST%"
)

exit /B 0
