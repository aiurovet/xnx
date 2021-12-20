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
  [Switch] $Recurse
)

################################################################################
# Adjust command-line parameters
################################################################################

If (!$Recurse) {
  $Depth = 0
}

################################################################################
# Set internal parameters
################################################################################

$ScriptName = [System.IO.Path]::GetFileName($PSCommandPath)

################################################################################
# Check command-line parameters and print usage if failed
################################################################################

If ($Path.Length -le 0) {
  Write-Host "`nUSAGE: $ScriptName -Path <comma-separated-list> [-Recurse] [-Depth <number>] [-Include <mask>] [-Exclude <mask>] [-Expected <number>]`n"
  Exit 1
}

################################################################################

$Actual = (Get-ChildItem -Path "$Path" -Include "$Include" -Exclude "$Exclude" -Depth $Depth).Count;
$LastExitCode = If ($?) { 0 } Else { 1 }

If ($Expected -le [System.Int32]::MinValue) {
  $Actual | Out-Host;
}
Else {
  If ($Actual -ne $Expected) {
    $LastExitCode = 1
  }
}

Exit $LastExitCode

################################################################################
