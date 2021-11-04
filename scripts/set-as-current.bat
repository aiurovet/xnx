@echo off

@rem **************************************************************************
@rem * Copyright (C) Alexander Iurovetski 2021. All rights reserved
@rem *
@rem * The script to run after unpacking the installation archive in order to
@rem * point to this version (the deepest-level containing sub-directory)
@rem **************************************************************************

setlocal EnableDelayedExpansion

@rem **************************************************************************
@rem * Initialise the error flag and the startup directory
@rem **************************************************************************

set ERR=0
set ORG_DIR=%CD%
set JOB_NAME=%~n0

echo.

@rem **************************************************************************
@rem * Check whether the help screen is requested
@rem **************************************************************************

if /I "%~1" == "-?" goto USAGE
if /I "%~1" == "/?" goto USAGE

@rem **************************************************************************
@rem * Get the version-specific directory as either the first argument, or as
@rem * the script's containing directory path when no argument passed. Then
@rem * check and remove trailing directory separator character if found
@rem **************************************************************************

if "%~1" == "" (set VER_DIR=%~dp0) else (set VER_DIR=%~1)
if "%VER_DIR:~-1%" == "\" (set VER_DIR=%VER_DIR:~0,-1%)

shift

if not "%~1" == "" (
  echo.
  echo Invalid number of arguments passed: zero or one expected
  goto USAGE
)

@rem **************************************************************************
@rem * Get the path of the directory containing all version sub-directories
@rem * (one level up above the script's directory) as well as the version name
@rem * which is the name of the lowest-level directory containing the script
@rem **************************************************************************

for %%i in ("%VER_DIR%") do (
  set VER_PARENT=%%~dpi
  set VER_NAME=%%~nxi
)

@rem **************************************************************************
@rem * Switch to the directory containing all version directories
@rem **************************************************************************

echo Switching to "%VER_PARENT%"
cd "%VER_PARENT%"
if errorlevel 1 goto :FAIL

@rem **************************************************************************
@rem * Delete (if found) and create the directory link:
@rem *
@rem * current -> (the-actual-version)
@rem *
@rem * Under Windows, this requires to run the script with the elevated (admin)
@rem * access regardless the directory accessibility
@rem **************************************************************************

if "%VER_NAME%" == "current" (
  echo Cannot point to itself
  goto FAIL
)

if exist "%VER_NAME%" (
  if exist current (rmdir current)
  mklink /D current "%VER_NAME%"
  if errorlevel 1 goto :FAIL
) else (
  echo Sub-directory does not exist: "%VER_NAME%"
  goto FAIL
)

@rem **************************************************************************
@rem * The exit point
@rem **************************************************************************

:QUIT

if not "%ORG_DIR%" == "" (cd "%ORG_DIR%")
exit /B %ERR%

@rem **************************************************************************
@rem * The point of failure
@rem **************************************************************************

:FAIL

echo.
echo The script failed

set ERR=1
goto :QUIT

@rem **************************************************************************
@rem * Usage
@rem **************************************************************************

:USAGE

echo.
echo USAGE: ^<path^>\%JOB_NAME% [^<directory^>]
echo NOTES: the default directory is ^<path^> (the one containing the script)

set ERR=1
goto :QUIT

@rem **************************************************************************
