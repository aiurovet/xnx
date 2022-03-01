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

$Command = "Get-ChildItem"; Write-Host "DBG: 1: $Command";

if ($Recurse) { $Command = "$Command -Recurse"; Write-Host "DBG: 2: $Command"; }
if ($Path) { $Command = "$Command -Path `"$Path`""; Write-Host "DBG: 3: $Command"; }
if ($Filter) { $Command = "$Command -Filter `"$Filter`""; Write-Host "DBG: 4: $Command"; }
if ($Depth) { $Command = "$Command -Depth $Depth"; Write-Host "DBG: 5: $Command"; }
if ($Include) { $Command = "$Command -Include `"$Include`""; Write-Host "DBG: 6: $Command"; }
if ($Exclude) { $Command = "$Command -Exclude `"$Exclude`""; Write-Host "DBG: 7: $Command"; }

if ($Pattern) { $Pattern = $Pattern -replace "`"", "```"";
                $Command = "$Command | Get-Content | Select-String -Pattern `"$Pattern`""; Write-Host "DBG: 8: $Command"; }

Write-Host "DBG: 9: $Command";

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
