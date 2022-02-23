@echo off

@rem ***************************************************************************
@rem Switching to the project's top directory
@rem ***************************************************************************

@echo Switching to the project's top directory

pushd

%~d0
if errorlevel 1 (popd; exit /B 1)

cd "%~dp0.."
if errorlevel 1 (popd; exit /B 1)

set TOP=%CD%

@rem ***************************************************************************

cd "%TOP%\examples\flutter_app_icons"
if errorlevel 1 (popd; exit /B 1)

echo Cleaning in: %CD%
rmdir /S /Q android ios web
if errorlevel 1 (popd; exit /B 1)

@rem ***************************************************************************

cd "%TOP%\examples\ms_office"
if errorlevel 1 (popd; exit /B 1)

echo Cleaning in: %CD%
rmdir /S /Q out
if errorlevel 1 (popd; exit /B 1)

@rem ***************************************************************************

cd "%TOP%\examples\multi_conf"
if errorlevel 1 (popd; exit /B 1)

echo Cleaning in: %CD%
rmdir /S /Q out
if errorlevel 1 (popd; exit /B 1)

@rem ***************************************************************************

cd "%TOP%\examples\site_env"
if errorlevel 1 (popd; exit /B 1)

echo Cleaning in: %CD%
rmdir /S /Q out
if errorlevel 1 (popd; exit /B 1)

@rem ***************************************************************************

cd "%TOP%\examples\web_config"
if errorlevel 1 (popd; exit /B 1)

echo Cleaning in: %CD%
rmdir /S /Q out
if errorlevel 1 (popd; exit /B 1)

@rem ***************************************************************************

echo Completed
popd
exit /B 0

@rem ***************************************************************************
