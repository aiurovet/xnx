# Get-FileHash -Algorithm SHA256 -Path "$env:USERPROFILE\Projects\choco\xnx\*.zip"

$ErrorActionPreference = 'Stop';

$packageArgs = @{
  packageName    = 'xnx'
  unzipLocation  = $toolsDir
  fileType       = 'exe'
  softwareName   = 'xnx*'
  #url64bit       = 'https://github.com/aiurovet/xnx/raw/0.1.0/app/Windows/xnx-0.1.0-windows-x86_64.zip'
  #checksum64     = 'c0426374b7722d7ee3e33a757c080248e38ebfb79553b3043eb85d16386f8b53'
  #checksumType64 = 'sha256' # certutil -hashfile <file> SHA256
}

#Invoke-WebRequest -URI $packageArgs.url64bit
Install-ChocolateyPackage @packageArgs
