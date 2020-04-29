@echo off

rem ############################################################################
rem Depends on zip.exe (can be downloaded as part of GnuWin32)
rem ############################################################################

set DIR=%1
set OUT=%2

rem ############################################################################

if "%DIR%" == "" goto FAIL
if "%OUT%" == "" goto FAIL

cd "%DIR%"
if errorlevel 1 goto FAIL

zip -m -r "%OUT%" *
if errorlevel 1 goto FAIL

cd ..
if errorlevel 1 goto FAIL

del /F/Q/S "%DIR%" > nul
if errorlevel 1 goto FAIL

rem ############################################################################

:GOOD
exit /B 0

:FAIL
echo Failed to zip "%DIR%" to "%OUT%"
exit /B 1

rem ############################################################################
