@echo off

rem ############################################################################
rem Depends on unzip.exe (can be downloaded as part of GnuWin32)
rem ############################################################################

set DIR=%1
set INP=%2

rem ############################################################################

if "%INP%" == "" goto FAIL
if "%DIR%" == "" goto FAIL

mkdir "%DIR%"
if errorlevel 1 goto FAIL

unzip -o -d "%DIR%" "%INP%"
if errorlevel 1 goto FAIL

rem ############################################################################

:GOOD
exit /B 0

:FAIL
echo Failed to unzip "%2" to "%1"
exit /B 1

rem ############################################################################
