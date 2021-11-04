@echo off

setlocal EnableDelayedExpansion

@rem ***************************************************************************
@rem This script should be run from the project's top folder
@rem ***************************************************************************

set PRJ=xnx
set VER=0.1.0

@rem ***************************************************************************

set EXE=bin\%PRJ%.exe
set APP=app\Windows
set OUP=out\Windows
set OUT=%OUP%\%PRJ%\%VER%
set PKG=%APP%\%PRJ%-%VER%_windows_x86_64

@rem ***************************************************************************

%~d0
if errorlevel 1 exit /B 1

cd "%~dp0.."
if errorlevel 1 exit /B 1

set OPT_KEEP=0

:loop

if /I "%~1" == "/K" (
  set OPT_KEEP=1
) else (
  set ARGS=!ARGS! %1
)

shift
if "%~1" neq "" goto :loop

@rem Reset errorlevel
ver > nul

@rem ***************************************************************************

echo Running the build for Windows

echo Creating the application directory "%APP%"
mkdir "%APP%"
if errorlevel 1 exit /B 1

if exist "%OUP%" (
  echo Discarding the output parent directory "%OUP%"
  rmdir /Q /S "%OUP%"
)

echo Creating the output directory "%OUT%"
mkdir "%OUT%"
if errorlevel 1 exit /B 1

@rem ***************************************************************************

echo Getting the latest version of the packages
call dart pub get
if errorlevel 1 exit /B 1

echo Compiling "%EXE%"
dart compile exe bin\main.dart -o "%EXE%"
if errorlevel 1 exit /B 1

echo Copying the executable file to the output directory
copy /Y "%EXE%" "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the version switcher to the output directory
copy /Y scripts\set-as-current.bat "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the change log
copy /Y CHANGELOG.md "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the installation guide
copy /Y INSTALL.md "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the license
copy /Y LICENSE "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the examples
xcopy /I /Q /S examples "%OUT%\examples"
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
"%EXE%" -d scripts\mkicons "%PRJ%" "..\..\%OUT%" !ARGS!
if errorlevel 1 exit /B 1

echo Creating and compressing the application package
"%EXE%" --move --pack "%OUP%" "%PKG%.zip"

@rem ***************************************************************************

echo Removing the output parent directory "%OUP%"
rmdir /Q /S "%OUP%"

if %OPT_KEEP% equ 0 (
  echo Removing the binary
  del /Q "%EXE%"
)

@rem ***************************************************************************

echo The build successfully completed
exit /B 0

@rem ***************************************************************************
