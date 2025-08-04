param(
  [string]$logstashFqdn,
  [string]$logstashIp
)

$ErrorActionPreference = 'Stop'

# --- 1. Install Log Source Prerequisites ---
Write-Host "Installing prerequisite log sources..."

iwr -Uri "https://github.com/smashtitle/EventLog-Baseline-Guide/raw/refs/heads/main/bat/ASD-Servers.bat" -OutFile "C:\\Windows\\Temp\ASD-Servers.bat"
Start-Process "C:\Windows\Temp\ASD-Servers.bat" -Wait

# Install RPC Firewall
iwr -Uri "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip" -OutFile "C:\Windows\Temp\RPCFW_2.2.5.zip"
Expand-Archive -Path "C:\Windows\Temp\RPCFW_2.2.5.zip" -DestinationPath "C:\Tools" -Force
# Use Start-Process with -Wait to ensure the installer finishes
Start-Process "cmd.exe" -ArgumentList '/c "C:\Tools\RPCFW_2.2.5\RpcFwManager.exe /install"' -Wait

# Install Sysmon
iwr -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "C:\Windows\Temp\Sysmon.zip"
Expand-Archive -Path "C:\Windows\Temp\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force
iwr -Uri "https://github.com/smashtitle/sysmon-modular/raw/refs/heads/master/sysmonconfig-research.xml" -OutFile "C:\Tools\Sysmon\sysmonconfig-research.xml"
# Use the primary config file for installation
Start-Process "C:\Tools\Sysmon\Sysmon64.exe" -ArgumentList '-accepteula -i C:\Tools\Sysmon\sysmonconfig-research.xml' -Wait

# --- 2. Install and Configure Winlogbeat ---
Write-Host "Installing and configuring Winlogbeat..."

$winlogbeatVersion = '9.1.0'
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

# Copy the custom winlogbeat.yml to the staged source directory
Copy-Item -Path '.\winlogbeat.yml' -Destination (Join-Path $sourceDir 'winlogbeat.yml') -Force

# Perform token replacement on the staged winlogbeat.yml
$configFile = Join-Path $sourceDir 'winlogbeat.yml'
(Get-Content $configFile) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content $configFile

Write-Host 'Installing Winlogbeat to Program Files...'
New-Item -Path $installRoot -ItemType Directory -Force | Out-Null
Copy-Item -Path "$sourceDir\*" -Destination $installRoot -Recurse -Force

Push-Location $installRoot
powershell.exe -ExecutionPolicy Bypass -File ".\install-service-winlogbeat.ps1"
& .\install-service-winlogbeat.ps1
Pop-Location

Write-Host "Starting Winlogbeat service..."
Start-Service -Name winlogbeat

Write-Host "Workstation setup complete."
