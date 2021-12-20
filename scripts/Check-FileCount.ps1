#!/usr/bin/env pwsh

################################################################################
# Define command-line parameters
################################################################################

Param(
  [Switch]   $Help,
  [Switch]   $Quiet,
  [Switch]   $Recurse,

  [String[]] $Path     = @(),
  [String]   $Include  = "",
  [String]   $Exclude  = "",
  [Int32]    $Depth    = [System.Int32]::MaxValue,
  [Int32[]]  $Expected = @()
)

################################################################################
# Adjust command-line parameters and set internal parameters
################################################################################

If (!$Recurse) {
  $Depth = 0
}

$ScriptName = [System.IO.Path]::GetFileName($PSCommandPath)

################################################################################
# Check command-line parameters and print usage if failed
################################################################################

If ($Help -Or !$Path) {
  Write-Host "HERE"

  Write-Host @"

USAGE:

$ScriptName [OPTIONS]

OPTIONS:

-Help           - this help screen
-Quiet          - do not print anything
-Recurse        - recurse (scan all) sub-directories (maximum depth)
-Path <list>    - a comma-separated list of directories and/or files (the wildcards are allowed)
-Depth <num>    - how deep the directory tree should be scanned (default: 0 in the non-recursive mode)
-Include <mask> - fetch only those filenames (the wildcards are allowed)
-Exclude <mask> - skip those filenames (the wildcards are allowed)
-Expected <num>|<min>,<max> - succeed only if the number of directories and/or files matches (default: don't check)

"@

  Exit 1
}

################################################################################

If ($Expected.Length -ge 1) {
  $ExpectedMin = $Expected[0];
  $ExpectedMax = $Expected[$Expected.Length - 1];
}
Else {
  $ExpectedMin = [System.Int32]::MinValue;
  $ExpectedMax = [System.Int32]::MinValue;
}

################################################################################

$Actual = (Get-ChildItem -Path "$Path" -Include "$Include" -Exclude "$Exclude" -Depth $Depth).Count;
$LastExitCode = If ($?) { 0 } Else { 1 }

If ($ExpectedMin -le [System.Int32]::MinValue) {
  if (!$Quiet) {
    Write-Output "${ScriptName}: Found: $Actual";
  }
}
Else {
  If (($Actual -lt $ExpectedMin) -Or ($Actual -gt $ExpectedMax)) {
    $LastExitCode = 1
  }

  $Result = If ($LastExitCode -eq 0) { "Success" } Else { "Failure" }

  if (!$Quiet) {
    if ($ExpectedMin -eq $ExpectedMax) {
      Write-Output "${ScriptName}: ${Result}: $Actual == $ExpectedMin";
    }
    Else {
      Write-Output "${ScriptName}: ${Result}: $ExpectedMin <= $Actual <= $ExpectedMax";
    }
  }
}

Exit $LastExitCode

################################################################################
