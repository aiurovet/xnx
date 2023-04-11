@echo off
 
setlocal EnableDelayedExpansion

@rem ***************************************************************************
@rem This script removes generated files from xnx\examples directory
@rem ***************************************************************************

set DIR=%~dp0

@rem ***************************************************************************

for %%d in (
    %DIR%flutter_app_icons\android,
    %DIR%flutter_app_icons\ios,
    %DIR%flutter_app_icons\linux,
    %DIR%flutter_app_icons\macos,
    %DIR%flutter_app_icons\web,
    %DIR%flutter_app_icons\windows,
    %DIR%ms_office\out,
    %DIR%ms_office\unz,
    %DIR%multi_conf\out,
    %DIR%multi_icon\out,
    %DIR%site_env\ReleaseFiles,
    %DIR%web_config\out
  ) do (
  if exist "%%d" (
    echo.
    echo Cleaning: "%%d"
    rmdir /Q /S "%%d"
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
