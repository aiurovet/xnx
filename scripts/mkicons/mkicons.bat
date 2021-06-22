@echo off

cd "%~dp0\..\.."

set PRJ_NAME=doul
set PRJ_EXE=bin\Windows\%PRJ_NAME%.exe

if not exist "%PRJ_EXE%" (
  echo Executable file "%PRJ_EXE%" not found. Performing build.
  call scripts\build.bat
  if errorlevel 1 goto FAILURE
)

if not exist "%PRJ_EXE%" goto FAILURE

reg query HKLM\Software\Wine > nul
if not errorlevel 1 set WINE=1

echo Path: %PATH%
echo Testing: mkicons -version
mkicons -version

"%PRJ_EXE%" -d "scripts\\mkicons" %*
if errorlevel 1 goto FAILURE

@echo off

:SUCCESS
echo %~nx0 successfully completed
exit /B 0

:FAILURE
echo %~nx0 failed
exit /B 1
