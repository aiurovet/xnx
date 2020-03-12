@echo off
set BIN=%~dp0\bin
dart2native "%BIN%\doul.dart" -o "%BIN%\windows\doul.exe"