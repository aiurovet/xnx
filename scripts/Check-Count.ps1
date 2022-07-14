#!/usr/bin/env pwsh

################################################################################

Param(
  [Switch]   $Quiet,
  [Switch]   $Recurse,

  [String[]] $Path,
  [String]   $Pattern,
  [String]   $Filter,
  [String]   $Include,
  [String]   $Exclude,
  [Int32]    $Depth,
  [Int32[]]  $Expected
)

$ScriptName = [System.IO.Path]::GetFileName($PSCommandPath)

################################################################################

If ($Expected.Length -Ge 1) {
  $ExpectedMin = $Expected[0]
  $ExpectedMax = $Expected[$Expected.Length - 1]
}
Else {
  $ExpectedMin = [System.Int32]::MinValue
  $ExpectedMax = [System.Int32]::MinValue
}

################################################################################

$Command = "Get-ChildItem"

$ToChar = [IO.Path]::DirectorySeparatorChar
$FromChar = ($ToChar -Eq "/" ? "\\" : "/")

if ($Path) { $Path = $Path -Replace $FromChar, $ToChar }
if ($Filter) { $Filter = $Filter -Replace $FromChar, $ToChar }
if ($Include) { $Include = $Include -Replace $FromChar, $ToChar }
if ($Exclude) { $Exclude = $Exclude -Replace $FromChar, $ToChar }

$Cwd = [IO.Directory]::GetCurrentDirectory()

Write-Output "`nDBG: Cwdy: $Cwd`nDBG: Path: $Path`nDBG: Fltr: $Filter`nDBG: Incl: $Include`nDBG: Excl: $Exclude`n";

if ($Recurse) { $Command = "$Command -Recurse" }
if ($Path) { $Command = "$Command -Path `"$Path`"" }
if ($Filter) { $Command = "$Command -Filter `"$Filter`"" }
if ($Depth) { $Command = "$Command -Depth $Depth" }
if ($Include) { $Command = "$Command -Include `"$Include`"" }
if ($Exclude) { $Command = "$Command -Exclude `"$Exclude`"" }

if ($Pattern) { $Pattern = $Pattern -replace "`"", "```"";
                $Command = "$Command | Get-Content | Select-String -Pattern `"$Pattern`""; }

$Actual = (Invoke-Expression -Command "$Command").Count
$LastExitCode = If ($?) { 0 } Else { 1 }

If ($ExpectedMin -Le [System.Int32]::MinValue) {
  if (!$Quiet) {
    Write-Output "${ScriptName}: Found: $Actual"
  }
}
Else {
  If (($Actual -Lt $ExpectedMin) -Or ($Actual -Gt $ExpectedMax)) {
    $LastExitCode = 1
  }

  $Result = If ($LastExitCode -Eq 0) { "Success" } Else { "Failure" }

  if (!$Quiet) {
    if ($ExpectedMin -Eq $ExpectedMax) {
      Write-Output "${ScriptName}: ${Result}: $Actual (actual) == $ExpectedMin (expected)"
    }
    Else {
      Write-Output "${ScriptName}: ${Result}: $ExpectedMin (min) <= $Actual (actual) <= $ExpectedMax (max)"
    }
  }
}

################################################################################

Exit $LastExitCode

################################################################################
