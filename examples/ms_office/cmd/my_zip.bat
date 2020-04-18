@echo off

rem ############################################################################
rem Depends on zip.exe (can be downloaded as part of GnuWin32)
rem ############################################################################

if "%2" == "" goto FAIL
if not "%3" == "" goto FAIL

rem ############################################################################

DIR=%1
OUT=%2

rem ############################################################################

cd "%OUT%"
if errorlevel 1 goto FAIL

zip -m -r "%OUT%" *
if errorlevel 1 goto FAIL

cd ..
if errorlevel 1 goto FAIL

del /F/Q/S "%DIR%" > nul

:SUCCESS
exit /B 0

:FAIL
exit /B 1

rem ############################################################################
