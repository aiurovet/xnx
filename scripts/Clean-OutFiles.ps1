#!/usr/bin/env pwsh

################################################################################

Param(
  [Switch] $Quiet
)

################################################################################

$SubFolders = @(
  "examples/flutter_app_icons/android",
  "examples/flutter_app_icons/ios",
  "examples/flutter_app_icons/web",
  "examples/ms_office/out",
  "examples/multi_conf/out",
  "examples/multi_icon/out",
  "examples/site_env/out",
  "examples/site_env/web_config",
  "out",
  "scripts/mkicons/png",
  ""
)

################################################################################

$AppDir = [System.IO.Path]::GetDirectoryName($PSCommandPath)
$TopDir = [System.IO.Path]::GetDirectoryName($AppDir)

################################################################################

ForEach ($subFolder in $SubFolders) {
  If ($subFolder -eq "") {
    Break
  }

  $entity = Join-Path -Path "$TopDir" -ChildPath "$subFolder"

  If (Test-Path -Path "$entity") {
    If (!$Quiet) {
      Write-Output "Deleting: $entity"
    }
    Remove-Item -Path "$entity" -Recurse
  }
}

################################################################################

if (!$Quiet) {
  Write-Output "Completed"
}

################################################################################

Exit $LastExitCode

################################################################################
