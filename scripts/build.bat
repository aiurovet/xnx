@echo off

set PRJ=doul
set BIN=bin
set OST=Windows
set BIN_OST=%BIN%\%OST%

%~d0
if errorlevel 1 exit /B 1

cd %~dp0..
if errorlevel 1 exit /B 1

call pub get
if errorlevel 1 exit /B 1

call dart2native "%BIN%\main.dart" -o "%BIN_OST%\%PRJ%.exe"
if errorlevel 1 exit /B 1

set OSTYPE=%OST%
call scripts\mkicons\mkicons
if errorlevel 1 exit /B 1

copy /Y "README.md" "%BIN_OST%"
if errorlevel 1 exit /B 1

exit /B 0
