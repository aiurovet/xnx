#!/usr/bin/env pwsh

################################################################################
# Define command-line parameters
################################################################################

Param(
  [Parameter(Mandatory=$false)] [String] $Path = '',
  [Parameter(Mandatory=$false)] [String] $Include = '',
  [Parameter(Mandatory=$false)] [String] $Exclude = '',
  [Parameter(Mandatory=$false)] [Int32] $Depth = [System.Int32]::MaxValue,
  [Parameter(Mandatory=$false)] [Int32] $Expected = [System.Int32]::MinValue,
  [Switch] $Help,
  [Switch] $Quiet,
  [Switch] $Recurse
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

If (($Help) || ($Path.Length -le 0)) {
  Write-Host @"

USAGE:

$ScriptName [OPTIONS]

OPTIONS:

-Help              - this help screen
-Quiet             - do not print anything
-Recurse           - scan all sub-directories (max depth)
-Path <list>       - a comma-separated list of directories and/or files (the wildcards are allowed)
-Depth <number>    - how deep the directory tree should be scanned (default: 0 in the non-recursive mode)
-Include <mask>    - fetch only those filenames (the wildcards are allowed)
-Exclude <mask>    - skip those filenames (the wildcards are allowed)
-Expected <number> - succeed only if the number of directories and/or files equals this one (default: don't check)

"@

  Exit 1
}

################################################################################

if (!$Quiet) {
  Write-Host "`n$ScriptName started`n";
}

################################################################################

$Actual = (Get-ChildItem -Path "$Path" -Include "$Include" -Exclude "$Exclude" -Depth $Depth).Count;
$LastExitCode = If ($?) { 0 } Else { 1 }

If ($Expected -le [System.Int32]::MinValue) {
  if (!$Quiet) {
    Write-Output "Actual: $Actual";
  }
}
Else {
  If ($Actual -ne $Expected) {
    $LastExitCode = 1
  }

  $Result = If ($LastExitCode -eq 0) { "OK" } Else { "Failed" }

  if (!$Quiet) {
    Write-Output "Actual: $Actual`nExpected: $Expected`nResult: $Result";
  }
}

if (!$Quiet) {
  Write-Host "`n$ScriptName completed`n";
}

Exit $LastExitCode

################################################################################
