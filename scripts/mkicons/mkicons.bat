@echo off

rem Reset errorlevel
ver > nul

%~d0
if errorlevel 1 exit /B 1

cd %~dp0..\..
if errorlevel 1 exit /B 1

set PRJ=xnx

"out\%PRJ%" -d scripts\mkicons %*
if errorlevel 1 goto FAILURE

@echo off

:SUCCESS
echo %~nx0 successfully completed
exit /B 0

:FAILURE
echo %~nx0 failed
exit /B 1
