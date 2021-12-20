#!/usr/bin/env pwsh

################################################################################

if ($Args.Count -le 1)
{
    Write-Host "`nUSAGE: Check-FileCount <expected-count> <files1> [<files2>...]`n";
    Exit 1
}

################################################################################

$ExpectedCount = $Args[0];
$FileMasks = $Args[1..$Args.Count];

################################################################################

(Get-ChildItem -Path $FileMasks).Count |`
  Select-String -Quiet -Pattern "^[ \t]*$ExpectedCount[ \t]*$"

################################################################################

Exit $LastExitCode

################################################################################
