param(
  [string]$logstashFqdn,
  [string]$logstashIp
)

$ErrorActionPreference = 'Stop'
$winlogbeatVersion = '9.0.3'
$archiveName       = "winlogbeat-$winlogbeatVersion-windows-x86_64.zip"
$downloadUri       = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$archiveName"
$installRoot       = 'C:\Program Files\Winlogbeat'
$tempPath          = Join-Path $env:TEMP 'winlogbeat-install'

New-Item -Path $tempPath -ItemType Directory -Force | Out-Null

iwr -Uri "https://github.com/smashtitle/EventLog-Baseline-Guide/raw/refs/heads/main/bat/ASD-Servers.bat" -OutFile "C:\\Windows\\Temp\ASD-Servers.bat"
& "C:\Windows\Temp\ASD-Servers.bat" -Wait

iwr -Uri "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip" -OutFile "C:\Windows\Temp\RPCFW_2.2.5.zip"
Expand-Archive -Path "C:\Windows\Temp\RPCFW_2.2.5.zip" -DestinationPath "C:\Tools"
cmd.exe /c "cd C:\Tools\RPCFW_2.2.5\ && C:\Tools\RPCFW_2.2.5\RpcFwManager.exe /install"
iwr -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "C:\Windows\Temp\Sysmon.zip"
Expand-Archive -Path "C:\Windows\Temp\Sysmon.zip" -DestinationPath "C:\Tools\Sysmon"
iwr -Uri "https://github.com/smashtitle/sysmon-modular/raw/refs/heads/master/sysmonconfig-research.xml" -OutFile "C:\Tools\Sysmon\sysmonconfig-research.xml"
iwr -Uri "https://github.com/smashtitle/sysmon-modular/blob/master/sysmon-null.xml" -OutFile "C:\Tools\Sysmon\sysmon-null.xml"
cmd.exe /c "C:\Tools\Sysmon\Sysmon64.exe -accepteula -i"

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
(Get-Content $configFile) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content $configFile

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
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oloruntolaallbert/public/main/ConfigureWinRM.ps1' -OutFile $winRmScript
    & powershell.exe -ExecutionPolicy Bypass -File $winRmScript
} catch {
    Write-Warning "WinRM hardening failed: $_"
}
