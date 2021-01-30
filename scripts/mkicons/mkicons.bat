@echo off

cd "%~dp0\..\.."

set PRJ_NAME=doul
set PRJ_EXE=bin\windows\%PRJ_NAME%.exe

@echo on
if not exist "%PRJ_EXE%" (
  echo Executable file "%PRJ_EXE%" not found. Performing build.
  call scripts\build.bat
)

if not exist "%PRJ_EXE%" goto FAILURE

"%PRJ_EXE%" -d "scripts/mkicons/" -c mkicons %*

@echo off

:SUCCESS
echo %~nx0 successfully completed
exit /B 0

:FAILURE
echo %~nx0 failed
exit /B 1
