@echo off

set PRJ=doul
set BIN=bin
set BIN_OS=%BIN%\windows

%~d0
if errorlevel 1 exit /B 1

cd %~dp0..
if errorlevel 1 exit /B 1

call pub get
if errorlevel 1 exit /B 1

call dart2native "%BIN%\main.dart" -o "%BIN_OS%\%PRJ%.exe"
if errorlevel 1 exit /B 1

@echo on

copy /Y "README.md" "%BIN_OS%"
if errorlevel 1 exit /B 1

exit /B 0
