Param(
  [string] $publisherVersion,
  [string] $path,
  [string] $outputPath,
  [string] $version,
  [string] $publisherFilePath
)
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

$workingDirectory = New-TemporaryDirectory

try{
  
  if(-not $publisherFilePath){
    curl https://github.com/HL7/fhir-ig-publisher/releases/download/$publisherVersion/publisher.jar -o "$($workingDirectory)/publisher.jar"
    $publisherFilePath = "$($workingDirectory)/publisher.jar"
  }

  
  Install-Module powershell-yaml

  $sourceFolder = "$($workingDirectory)/.source"
  $homeFolder   = "$($workingDirectory)/.home"
  $outputFolder = "$($workingDirectory)/.output"
  New-Item -ItemType Directory -Path $sourceFolder -Force
  New-Item -ItemType Directory -Path $homeFolder -Force
  New-Item -ItemType Directory -Path $outputFolder -Force
  
  Copy-Item -Path $path/* -Destination $sourceFolder -Force -Recurse

  $env:HOME = $homeFolder
  $env:USERPROFILE = $homeFolder
  $sushiFiles = $(Get-ChildItem -Path $sourceFolder -Include sushi-config.yaml -Recurse -Force).FullName
  foreach($sushiFile in $sushiFiles){
    $rootDirectory = [System.IO.Path]::GetFullPath($sourceFolder)
    $directory = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($sushiFile))
    $relativePath = $directory.Replace($rootDirectory,'')
    $relativePath = $relativePath -replace "^[\/\\]",""

    try{

      $command = @("pushd $rootDirectory")
      $command += "java -Xmx4G -jar $($publisherFilePath) -ig $relativePath"
      $command = $command -join "`n"
      Write-Host $command
      $command | Invoke-Expression
      New-Item -ItemType Directory -Path "$($outputFolder)/$($relativePath)" -Force
      Copy-Item -Path "$($directory)/output/*" -Destination "$($outputFolder)/$($relativePath)" -Force -Recurse
    }
    catch{
      throw $_.Exception
    }
    finally{
      popd
    }
  }

  
  Copy-Item -Path "$($outputFolder)/*" -Destination "$($outputPath)" -Force -Recurse
}
catch{
  throw $_.Exception
}
finally{
  Write-Host "Removing $($workingDirectory)"
  Remove-Item -Path $workingDirectory -Force -Recurse
}
