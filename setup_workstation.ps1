# Disable Defender settings, enable event providers, install Sysmon
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Disabling Windows Defender and PUA Protection..."
    Set-MpPreference -PUAProtection Disabled
    Set-MpPreference -DisableRealtimeMonitoring $true

    $toolsDir = "C:\Tools"
    $tempDir  = Join-Path $toolsDir "Temp"
    New-Item -Path $toolsDir, $tempDir -ItemType Directory -Force | Out-Null
    Add-MpPreference -ExclusionPath $toolsDir
    Write-Host "C:\Tools has been excluded from Defender scans."

    Write-Host "Applying event log baseline settings..."
    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/TelForge/main/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait

    Write-Host "Installing and configuring Sysmon..."
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
    Write-Host "Sysmon installation complete."
}
catch {
    Write-Error "Error during workstation setup: $($_.Exception.Message)"
    exit 1
}
