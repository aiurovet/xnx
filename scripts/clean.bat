@echo off
 
setlocal EnableDelayedExpansion

@rem ***************************************************************************
@rem This script removes generated files from xnx\examples directory
@rem ***************************************************************************

set DIR=%~dp0

@rem ***************************************************************************

for %%d in (
    %DIR%..\examples\flutter_app_icons\android,
    %DIR%..\examples\flutter_app_icons\ios,
    %DIR%..\examples\flutter_app_icons\linux,
    %DIR%..\examples\flutter_app_icons\macos,
    %DIR%..\examples\flutter_app_icons\web,
    %DIR%..\examples\flutter_app_icons\windows,
    %DIR%..\examples\ms_office\out,
    %DIR%..\examples\ms_office\unz,
    %DIR%..\examples\multi_conf\out,
    %DIR%..\examples\multi_icon\out,
    %DIR%..\examples\site_env\ReleaseFiles,
    %DIR%..\examples\web_config\out,
    %DIR%..\out
  ) do (
  if exist "%%d" (
    echo.
    echo Cleaning: "%%d"
    rmdir /Q /S "%%d"
    if errorlevel 1 goto FAIL
  )
)

@rem ***************************************************************************

for %%f in (
    %DIR%..\scripts\install\choco\*.nupkg
  ) do (
  if exist "%%f" (
    echo.
    echo Cleaning: "%%f"
    del /Q "%%f"
    if errorlevel 1 goto FAIL
  )
)

@rem ***************************************************************************
@rem Good exit point
@rem ***************************************************************************

:GOOD
set RET=0
set MSG=The cleanup successfully completed
goto QUIT

@rem ***************************************************************************
@rem Quit point
@rem ***************************************************************************

:QUIT
echo.
echo %MSG%
echo.
exit /B %RET%

@rem ***************************************************************************
@rem Error exit point
@rem ***************************************************************************

:FAIL
set RET=1
set MSG=The cleanup failed
goto QUIT

@rem ***************************************************************************
