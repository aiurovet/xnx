@echo off

setlocal EnableDelayedExpansion

@rem ***************************************************************************
@rem The entry point
@rem ***************************************************************************

set PRJ=xnx
set VER=0.2.0

@rem ***************************************************************************
@rem Initialising directory paths
@rem ***************************************************************************

set APP=app\Windows
set BIN=bin\Windows
set OUP=out\Windows
set OUT=%OUP%\%PRJ%

@rem ***************************************************************************
@rem Initialising file paths
@rem ***************************************************************************

set EXE=%BIN%\%PRJ%.exe
set PKG=%APP%\%PRJ%-%VER%-windows-x86_64

@rem ***************************************************************************
@rem Switching to the project's top directory
@rem ***************************************************************************

%~d0
if errorlevel 1 exit /B 1

cd "%~dp0.."
if errorlevel 1 exit /B 1

@echo Switched to the project's top directory "%CD%"

@echo Parsing the script's command-line arguments and grabbing possible extra ones

if not "%~1" == "" shift
set ARGS=%*

@rem ***************************************************************************

echo Running the build for Windows

if not exist "%APP%" (
  echo Creating the application directory "%APP%"
  mkdir "%APP%"
  if errorlevel 1 exit /B 1
)

if not exist "%BIN%" (
  echo Creating the bin directory "%BIN%"
  mkdir "%BIN%"
  if errorlevel 1 exit /B 1
)

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

echo Copying the change log to the output directory
copy /Y CHANGELOG.md "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the installation guide to the output directory
copy /Y INSTALL.md "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the license to the output directory
copy /Y LICENSE "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the application configuration file to the output directory
xcopy /Y "default.%PRJ%config" "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the examples to the output directory
xcopy /I /Q /S examples "%OUT%\examples"
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
"%EXE%" -d scripts\mkicons "%PRJ%" "..\..\%OUT%" %ARGS%
if errorlevel 1 exit /B 1

echo Creating and compressing the application package
"%EXE%" --move --pack "%OUP%\%PRJ%" "%PKG%.zip"

@rem ***************************************************************************

echo Removing the output parent directory "%OUP%"
rmdir /Q /S "%OUP%"

@rem ***************************************************************************

echo The build successfully completed
exit /B 0

@rem ***************************************************************************
