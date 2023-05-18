$ErrorActionPreference = 'Stop';

$packageArgs = @{
  packageName    = 'xnx'
  unzipLocation  = $toolsDir
  fileType       = 'exe'
  softwareName   = 'xnx*'
}

#Invoke-WebRequest -URI $packageArgs.url64bit
Install-ChocolateyPackage @packageArgs
