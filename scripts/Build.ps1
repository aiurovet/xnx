#!/bin/pwsh

################################################################################
# Application build script (Windows only)
# Copyright (c) 2023 Alexander Iurovetski
################################################################################

using namespace System.IO
using namespace System.Text.RegularExpressions

$ProjectName = "xnx"
$ProjectVer = "0.2.0"
$StartupDir = Get-Location

################################################################################
# This script info
################################################################################

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptBaseName = [Path]::GetFileName($ScriptPath)
$ProjectDir = (Get-Item $ScriptPath).Directory.Parent.FullName

################################################################################
# Global variables (compatible with PowerShell v5)
################################################################################

$IsOSWindows = if ($Env:USERPROFILE) {$true} else {$false}
$IsOSMacOS   = if (!$IsOSWindows -and (Test-Path "/Applications" -PathType Container)) {$true} else {$false}
$IsOSLinux   = if (!$IsOSWindows -and !$IsOSMacOS -and $Env:HOME) {$true} else {$false}
$LineBreak   = if ($IsOSWindows) {"`r`n"} else {"`n"}

$OSName      = if ($IsOSLinux) {"Linux"} `
               else {if ($IsOSMacOS) {"macOS"} `
               else {if ($IsOSWindows) {"Windows"} `
               else {$null}}}

$AppDir = [Path]::Combine($ProjectDir, "app", $OSName)
$BinDir = [Path]::Combine($ProjectDir, "bin", $OSName)
$ChocoDir = [Path]::Combine($ProjectDir, "scripts", "install", "choco")
$ExeExt = if ($IsOSWindows) {".exe"} else {""}
$ExePath = [Path]::Combine($BinDir, "$ProjectName$ExeExt")
$OutParentDir = [Path]::Combine($ProjectDir, "out", $OSName)
$OutDir = [Path]::Combine($OutParentDir, $ProjectName)

$Yes = "Yes"
$No = "No"

$global:OptBrew = $false
$global:OptChocoBuild = $false
$global:OptChocoPush = $false
$global:OptCompile = $false

################################################################################
# The entry point
################################################################################

function AppRun() {
  try {
    $LASTEXITCODE = 0

    Set-Location $ProjectDir
    Write-Output "Running the build for $OSName with $(LoadOptions)"

    CreateDirIfNotExists $AppDir "application"

    if ($global:OptCompile -or $global:OptIcons) {
      CreateDirIfNotExists $BinDir "bin"
      CreateDirIfNotExists $OutDir "output"
    }

    if ($global:OptCompile) {
      Write-Output "Getting the latest version of the packages"
      RunCommand "dart" @("pub", "get")

      Write-Output "Compiling $ProjectName $ProjectVer"
      $Script = [Path]::Combine($ProjectDir, "bin", "main.dart")
      RunCommand "dart" @("compile", "exe", $Script, "-o", $ExePath)
    }

    if ($global:OptIcons) {
      Write-Output "Creating the icons in the output directory"
      $Script = [Path]::Combine($ProjectDir, "scripts", "mkicons")
      RunCommand $ExePath @("-d", $Script, $ProjectName, $OutDir)
    }

    if ($global:OptChocoBuild) {
      Write-Output "Replacing hash in the verification file"
      ReplaceChecksum $ExePath
      ReplaceChecksum $ExePath -ToName "chocolateyinstall.ps1" -Pattern "(-Checksum64\s*[`"'])[0-9A-Fa-f]+"
      ReplaceChecksum ([Path]::Combine($ChocoDir, "xnx.ico"))
      ReplaceChecksum ([Path]::Combine($ChocoDir, "xnx_dark.ico"))

      Write-Output "Creating the Chocolatey package in `"$AppDir`""
      $NuspecPath = [Path]::Combine($ChocoDir, "$ProjectName.nuspec")
      RunCommand "choco" @("pack", $NuspecPath, "--outdir", $AppDir)
    }

    if ($global:OptChocoPush) {
      Set-Location $AppDir
      RunCommand "choco" @("push")
      Set-Location $ProjectDir
    } elseif ($global:OptChocoBuild) {
      Write-Output "`nPlease run ** choco push ** if needed`n"
    }

    Write-Output "The build successfully completed"
  } catch {
    Write-Output "The build failed"
    Exit 1
  } finally {
    CleanUp
  }
}

################################################################################

function CleanUp {
  if (Test-Path $OutParentDir -PathType Container) {
    Write-Output "Deleting the output parent directory `"$OutParentDir`""
    Remove-Item $OutParentDir -Recurse
  }

  Set-Location $StartupDir
}

################################################################################

function CreateDirIfNotExists {
  param ([string]$Dir, [string]$Hint)
  
  if (Test-Path $Dir -PathType Container) {
    return
  }

  $LASTEXITCODE = 0

  Write-Output "Creating the $Hint directory `"$Dir`""
  New-Item $Dir -ItemType "Directory" | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw
  }
}

################################################################################

function LoadOptions {
  $LASTEXITCODE = 0

  $oldExt = [Path]::GetExtension($ScriptBaseName)
  $newExt = ".options"

  if ($oldExt) {
    $optPath = [Path]::ChangeExtension($ScriptPath, $NewExt)
  } else {
    $optPath = "$ScriptPath$NewExt"
  }

  $text = Get-Content $optPath -Raw

  if ($LASTEXITCODE -ne 0) {
    throw
  }

  $text = $LineBreak + $text.Replace("[ `t]+", "").ToLower() + $LineBreak

  $global:OptBrew = $text.Contains("$LineBreak-brew$LineBreak")
  $global:OptChocoBuild = $text.Contains("$LineBreak-choco-build$LineBreak" )
  $global:OptChocoPush = $text.Contains("$LineBreak-choco-push$LineBreak" )
  $global:OptCompile = $text.Contains("$LineBreak-compile$LineBreak")
  $global:OptIcons = $text.Contains("$LineBreak-icons$LineBreak")

  $optStr = ""
  $optStr += ", compile=$(if ($global:OptCompile) {$Yes} else {$No})"
  $optStr += ", icons=$(if ($global:OptIcons) {$Yes} else {$No})"
  $optStr += ", brew=$(if ($global:OptBrew) {$Yes} else {$No})"
  $optStr += ", choco-build=$(if ($global:OptChocoBuild) {$Yes} else {$No})"
  $optStr += ", choco-push=$(if ($global:OptChocoPush) {$Yes} else {$No})"
  if (!$optStr) {$optStr += "<none>"}

  return $optStr.Substring(2)
}

################################################################################

function ReplaceChecksum {
  param ([string]$Path, [string]$ToName, [string]$Pattern)

  $LASTEXITCODE = 0

  if (!$ToName) {
    $ToName = "VERIFICATION.txt"
  }

  $ToPath = [Path]::Combine($ChocoDir, "tools", $ToName)

  Write-Output "Getting hash for $Path"
  $Hash = Get-FileHash $Path -Algorithm SHA256 | ForEach-Object {$_.Hash}

  if ($LASTEXITCODE -ne 0) {
    throw
  }

  Write-Output "...loading `"$ToPath`""

  $Text = (Get-Content $ToPath) -join "`n"

  if ($LASTEXITCODE -ne 0) {
    throw
  }

  if (!$Pattern) {
    $Pattern = "(?i)(\s*x64\s*URL:.*[`\`\`\/]" + `
              [Regex]::Escape([Path]::GetFileName($Path)) + `
              "\s*x64\s*Checksum\s*Type:\s*SHA[0-9]+\s*x64\s*Checksum:\s*)[0-9A-Fa-f]+"
  }

  $Text = $Text -replace $Pattern, "`${1}$Hash"

  Write-Output "...updating"
  Set-Content $ToPath -Value $Text

  if ($LASTEXITCODE -ne 0) {
    throw
  }
}

################################################################################

function RunCommand {
  param ([string]$CmdPath, [string[]]$CmdArgs)

  $LASTEXITCODE = 0

  & $CmdPath $CmdArgs

  if ($LASTEXITCODE -ne 0) {
    throw
  }
}

################################################################################

AppRun

################################################################################
