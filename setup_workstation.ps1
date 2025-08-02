param(
  [string]$EventHubFqdn,
  [string]$ConnectionString,
  [string]$SasKey,
  [string]$SasKeyName
)

$ErrorActionPreference = 'Stop'
$winlogbeatVersion = '9.0.3'
$archiveName       = "winlogbeat-$winlogbeatVersion-windows-x86_64.zip"
$downloadUri       = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$archiveName"
$installRoot       = 'C:\Program Files\Winlogbeat'
$tempPath          = Join-Path $env:TEMP 'winlogbeat-install'

New-Item -Path $tempPath -ItemType Directory -Force | Out-Null

Write-Host "Downloading Winlogbeat $winlogbeatVersion..."
Invoke-WebRequest -Uri $downloadUri -OutFile (Join-Path $tempPath $archiveName)

Write-Host 'Extracting archive...'
Expand-Archive -Path (Join-Path $tempPath $archiveName) -DestinationPath $tempPath -Force

Write-Host 'Installing to Program Files...'
Copy-Item -Path (Join-Path $tempPath "winlogbeat-$winlogbeatVersion-windows-x86_64\*") `
          -Destination $installRoot -Recurse -Force

Copy-Item -Path '.\winlogbeat.yml' -Destination (Join-Path $installRoot 'winlogbeat.yml') -Force

# Token replacement
$config = Join-Path $installRoot 'winlogbeat.yml'
(Get-Content .\winlogbeat.yml) `
  -replace '<NAMESPACE>', $EventHubFqdn `
  -replace '<EVENTHUB>', $eventHubName `      # Add this line
  -replace '<SASKEYNAME>', $SasKeyName `      # Add this line
  -replace '<SASKEY>', $SasKey `              # Add this line
  -replace '<CONNECTIONSTRING>', $ConnectionString |
  Set-Content 'C:\ProgramData\Winlogbeat\winlogbeat.yml'

Write-Host 'Installing Winlogbeat service...'
Push-Location $installRoot
& .\install-service-winlogbeat.ps1
Pop-Location

Start-Service -Name winlogbeat

# Optional WinRM hardening
try {
    $winRmScript = Join-Path $tempPath 'ConfigureWinRM.ps1'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oloruntolaallbert/public/main/ConfigureWinRM.ps1' `
                      -OutFile $winRmScript
    & powershell.exe -ExecutionPolicy Bypass -File $winRmScript
} catch {
    Write-Warning "WinRM hardening failed: $_"
}

Write-Host 'Winlogbeat setup complete.'
