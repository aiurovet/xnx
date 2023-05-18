################################################################################
# Application build script (Windows only)
# Copyright (c) 2023 Alexander Iurovetski
################################################################################

$ProjectName = "xnx"
$ProjectVer = "0.2.0"
$StartupDir = Get-Location

################################################################################
# This script info
################################################################################

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptBaseName = [IO.Path]::GetFileName($ScriptPath)
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

$AppDir = [IO.Path]::Combine($ProjectDir, "app", $OSName)
$BinDir = [IO.Path]::Combine($ProjectDir, "bin", $OSName)
$ChocoDir = [IO.Path]::Combine($ProjectDir, "scripts", "install", "choco")
$ExePath = [IO.Path]::Combine($BinDir, "$ProjectName.exe")
$OutParentDir = [IO.Path]::Combine($ProjectDir, "out", $OSName)
$OutDir = [IO.Path]::Combine($OutParentDir, $ProjectName)

$Yes = "Yes"
$No = "No"

$global:OptBrew = $false
$global:OptChoco = $false
$global:OptCompile = $false

################################################################################
# The entry point
################################################################################

function AppRun() {
  try {
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
      $Script = [IO.Path]::Combine($ProjectDir, "bin", "main.dart")
      RunCommand "dart" @("compile", "exe", $Script, "-o", $ExePath)
    }

    if ($global:OptIcons) {
      Write-Output "Creating the icons in the output directory"
      $Script = [IO.Path]::Combine($ProjectDir, "scripts", "mkicons")
      RunCommand $ExePath @("-d", $Script, $ProjectName, $OutDir)
    }

    if ($global:OptChoco) {
      Write-Output "Replacing hash in the verification file"
      ReplaceHash

      Write-Output "Creating the Chocolatey package in `"$AppDir`""
      $NuspecPath = [IO.Path]::Combine($ChocoDir, "$ProjectName.nuspec")
      RunCommand "choco" @("pack", $NuspecPath, "--outdir", $AppDir)
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
  $oldExt = [IO.Path]::GetExtension($ScriptBaseName)
  $newExt = ".options"

  if ($oldExt) {
    $optPath = [IO.Path]::ChangeExtension($ScriptPath, $NewExt)
  } else {
    $optPath = "$ScriptPath$NewExt"
  }

  $text = Get-Content $optPath -Raw
  $text = $LineBreak + $text.Replace("[ `t]+", "").ToLower() + $LineBreak

  $global:OptBrew = $text.Contains("$LineBreak-brew$LineBreak")
  $global:OptChoco = $text.Contains("$LineBreak-choco$LineBreak" )
  $global:OptCompile = $text.Contains("$LineBreak-compile$LineBreak")
  $global:OptIcons = $text.Contains("$LineBreak-icons$LineBreak")

  $optStr = ""
  $optStr += ", compile=$(if ($global:OptCompile) {$Yes} else {$No})"
  $optStr += ", icons=$(if ($global:OptIcons) {$Yes} else {$No})"
  $optStr += ", brew=$(if ($global:OptBrew) {$Yes} else {$No})"
  $optStr += ", choco=$(if ($global:OptChoco) {$Yes} else {$No})"
  if (!$optStr) {$optStr += "<none>"}

  return $optStr.Substring(2)
}

################################################################################

function ReplaceHash {
  Write-Output "Getting hash for $ExePath"
  $Hash = Get-FileHash -Path $ExePath -Algorithm SHA256 | ForEach-Object {$_.Hash}

  if ($LASTEXITCODE -ne 0) {
    throw
  }

  $File = [IO.Path]::Combine($ChocoDir, "tools", "VERIFICATION.txt")
  Write-Output "Loading file `"$File`""

  $Text = Get-Content -Path $File

  if ($LASTEXITCODE -ne 0) {
    throw
  }

  $Text = $Text -replace "(\s*x64\s*Checksum:\s*)[0-9A-Fa-f]+(.*)", "`${1}$Hash`${2}"

  Write-Output "Updating file `"$File`""
  Set-Content -Path $File -Value $Text

  if ($LASTEXITCODE -ne 0) {
    throw
  }
}

################################################################################

function RunCommand {
  param ([string]$CmdPath, [string[]]$CmdArgs)
  
  & $CmdPath $CmdArgs

  if ($LASTEXITCODE -ne 0) {
    throw
  }
}

################################################################################

AppRun

################################################################################
