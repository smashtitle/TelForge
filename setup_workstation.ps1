# Disable Defender settings, enable event providers, install Sysmon, configure WinRM and add firewall rules
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Disabling  Defender and PUA Protection"
    Set-MpPreference -PUAProtection Disabled
    Set-MpPreference -DisableRealtimeMonitoring $true

    Write-Host "Excluding C:\Tools from Defender scans"
    $toolsDir = "C:\Tools"
    $tempDir  = Join-Path $toolsDir "Temp"
    New-Item -Path $toolsDir, $tempDir -ItemType Directory -Force | Out-Null
    Add-MpPreference -ExclusionPath $toolsDir

    Write-Host "Applying event log baseline settings"
    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/TelForge/main/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait

    Write-Host "Installing/configuring Sysmon"
    $sysmonDir = Join-Path $toolsDir "Sysmon"
    New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null
    $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
    $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
    Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
    Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force
    $sysmonConfigUri = "https://raw.githubusercontent.com/smashtitle/TelForge/main/sysmonconfig-research.xml"
    $sysmonConfigXml = Join-Path $sysmonDir "sysmonconfig-research.xml"
    Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml
    $sysmonExe = Join-Path $sysmonDir "Sysmon.exe"
    Start-Process -FilePath $sysmonExe -ArgumentList "-accepteula", "-i", $sysmonConfigXml -Wait

    Write-Host "Configuring WinRM"
    Set-WSManQuickConfig -Force
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true

    Write-Host "Creating firewall rules for WinRM"
    New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}