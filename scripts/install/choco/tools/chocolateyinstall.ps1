$ErrorActionPreference = "Stop";

$app = $Env:ChocolateyPackageName

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition

Get-ChocolateyWebFile `
    -PackageName $app `
    -FileFullPath "$toolsDir\$app.exe" `
    -Url64bit "https://github.com/aiurovet/$app/raw/0.2.0/bin/Windows/$app.exe" `
    -Checksum64 "E6835D5B05B94C4A5C6EA430CA551403E3F12B403F7493F8A1ED584F9A06B799" `
    -ChecksumType64 "SHA256"
