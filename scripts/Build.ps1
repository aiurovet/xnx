################################################################################
# Application build script (Windows only)
# Copyright (c) 2023 Alexander Iurovetski
################################################################################

param(
  [switch] $ChocoOnly = $false,
  [switch] $IconsOnly = $false
)

$ErrorActionPreference = "Stop"

$ProjectName = "xnx"
$ProjectVer = "0.2.0"
$CanBuild = !$ChocoOnly -and !$IconsOnly

##############################################################################
# Initialising paths
##############################################################################

$ScriptPath = $MyInvocation.MyCommand.Path
$ProjectDir = (Get-Item $ScriptPath).Directory.Parent.FullName

$AppDir = "$ProjectDir\app\Windows"
$BinDir = "$ProjectDir\bin\Windows"
$ChocoDir = "$ProjectDir\scripts\install\choco"
$OutParentDir = "$ProjectDir\out\Windows"
$OutDir = "$OutParentDir\$ProjectName"

$ExePath = "$BinDir\$ProjectName.exe"

################################################################################
# The entry point
################################################################################

function AppRun() {
  Write-Output "Switching to the project's top directory to `"$ProjectDir`""
  Set-Location -Path $ProjectDir

  Write-Output "Running the build for Windows"

  CreateDirIfNotExists $AppDir "application"

  if (!$ChocoOnly) {
    CreateDirIfNotExists $BinDir "bin"
    CreateDirIfNotExists $OutDir "output"
  }

  if ($CanBuild) {
    Write-Output "Getting the latest version of the packages"
    RunCommand "dart" @("pub", "get")

    Write-Output "Compiling $ProjectName $ProjectVer"
    RunCommand "dart" @("compile", "exe", "bin\main.dart", "-o", $ExePath)
  }

  if ($IconsOnly) {
    Write-Output "Creating the icons in the output directory"
    RunCommand $ExePath @("-d", "scripts\mkicons", $ProjectName, $OutDir)
  }

  if ($ChocoOnly) {
    Write-Output "Replacing hash in the verification file"
    ReplaceHash

    Write-Output "Creating the Chocolatey package in `"$AppDir`""
    $NuspecPath = "$ChocoDir\$ProjectName.nuspec"
    RunCommand "choco" @("pack", $NuspecPath, "--outdir", $AppDir)
  }
  else {
    Write-Output "Deleting the output parent directory `"$OutParentDir`""
    Remove-Item $OutParentDir -Recurse
  }

  Write-Output "The build successfully completed"
}

################################################################################

function CreateDirIfNotExists {
  param ([String]$Dir, [String]$Hint)
  
  if (Test-Path -Path $Dir) {
    return
  }

  Write-Output "Creating the $Hint directory `"$Dir`""
  New-Item $Dir -ItemType "Directory" | Out-Null
}

################################################################################

function ReplaceHash {
  $Hash = Get-FileHash -Path $ExePath -Algorithm SHA256 | ForEach-Object {$_.Hash}
  $File = "$ChocoDir\tools\VERIFICATION.txt"
  $Text = Get-Content -Path $File
  $Text = $Text -replace "(\s*x64\s*Checksum:\s*)[0-9A-Fa-f]+(.*)", "`${1}$Hash`${2}"
  Set-Content -Path $File -Value $Text
}

################################################################################

function RunCommand {
  param ([String]$CmdPath, [String[]]$CmdArgs)
  
  & $CmdPath $CmdArgs
}

################################################################################

AppRun

################################################################################
