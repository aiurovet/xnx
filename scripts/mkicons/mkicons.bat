@echo off

rem Reset errorlevel
ver > nul

%~d0
if errorlevel 1 exit /B 1

cd %~dp0..\..
if errorlevel 1 exit /B 1

set PRJ_NAME=xnx
set PRJ_EXE=bin\Windows\%PRJ_NAME%\%PRJ_NAME%.exe

if not exist "%PRJ_EXE%" (
  echo Executable file "%PRJ_EXE%" not found. Performing build.
  call scripts\build.bat
  if errorlevel 1 goto FAILURE
)

if not exist "%PRJ_EXE%" goto FAILURE

"%PRJ_EXE%" -d scripts\mkicons %*
if errorlevel 1 goto FAILURE

@echo off

:SUCCESS
echo %~nx0 successfully completed
exit /B 0

:FAILURE
echo %~nx0 failed
exit /B 1
