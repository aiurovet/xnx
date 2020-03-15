@echo off

%~d0
if errorlevel 1 exit /B 1

cd %~dp0
if errorlevel 1 exit /B 1

call pub get
if errorlevel 1 exit /B 1

call dart2native "bin\doul.dart" -o "bin\windows\doul.exe"
if errorlevel 1 exit /B 1

exit /B 0
