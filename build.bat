@echo off
set BIN=%~dp0\bin

pub get
if errorlevel 1 exit /B 1

dart2native "%BIN%\doul.dart" -o "%BIN%\windows\doul.exe"
if errorlevel 1 exit /B 1

exit /B 0
