param(
  [string]$ConnectionString,
  [string]$eventHubName
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

$sourceDir = Join-Path $tempPath "winlogbeat-$winlogbeatVersion-windows-x86_64"

# --- Staging Phase ---
# 1. Copy the custom winlogbeat.yml to the staged source directory, overwriting the default.
Copy-Item -Path '.\winlogbeat.yml' -Destination (Join-Path $sourceDir 'winlogbeat.yml') -Force

# 2. Perform token replacement on the staged winlogbeat.yml.
$configFile = Join-Path $sourceDir 'winlogbeat.yml'
(Get-Content $configFile) `
  -replace '<CONNECTIONSTRING>', $ConnectionString `
  -replace '<EVENTHUB>', $eventHubName |
  Set-Content $configFile

# --- Installation Phase ---
Write-Host 'Installing to Program Files...'
# 3. Create the final installation directory.
New-Item -Path $installRoot -ItemType Directory -Force | Out-Null
# 4. Copy the fully prepared files to the final destination.
Copy-Item -Path "$sourceDir\*" -Destination $installRoot -Recurse -Force

Push-Location $installRoot
& .\install-service-winlogbeat.ps1
Pop-Location

Start-Service -Name winlogbeat

# WinRM hardening
try {
    $winRmScript = Join-Path $tempPath 'ConfigureWinRM.ps1'
    Invoke-WebRequest -Uri '[https://raw.githubusercontent.com/oloruntolaallbert/public/main/ConfigureWinRM.ps1](https://raw.githubusercontent.com/oloruntolaallbert/public/main/ConfigureWinRM.ps1)' `
                      -OutFile $winRmScript
    & powershell.exe -ExecutionPolicy Bypass -File $winRmScript
} catch {
    Write-Warning "WinRM hardening failed: $_"
}
