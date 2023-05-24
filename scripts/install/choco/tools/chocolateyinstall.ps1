$ErrorActionPreference = "Stop";

$app = $Env:ChocolateyPackageName

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition

Get-ChocolateyWebFile `
    -PackageName $app `
    -FileFullPath "$toolsDir\$app.exe" `
    -Url64bit "https://github.com/aiurovet/$app/raw/0.2.0/bin/Windows/$app.exe" `
    -Checksum64 "007D48B77E794CF6D5DC79053D9E99A02B2F888897AC7A500265CA92414BF71B" `
    -ChecksumType64 "SHA256"
