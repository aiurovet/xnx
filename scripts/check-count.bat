@echo off

set CNT=%~1
shift

if "%~1" != "" (
  for /F "tokens=*" %%v in ('dir /B %~* | find /v /c ""') do (
    if "%%v" == "%CNT%" (
      exit /B 0
    )
  )
)
else (
  echo.
  echo USAGE: %~nx0 ^<expected-count^> ^<files1^> [^<files2^>...]
  echo.
)

exit /B 1
