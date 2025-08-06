# Disable Defender settings, enable event providers, install Sysmon, and install Winlogbeat service
$ErrorActionPreference = 'Stop'

try {
    #region Defender and Baseline Configuration
    Set-MpPreference -PUAProtection Disabled
    Set-MpPreference -DisableRealtimeMonitoring $true

    $toolsDir = "C:\Tools"
    $tempDir  = Join-Path $toolsDir "Temp"
    New-Item -Path $toolsDir, $tempDir -ItemType Directory -Force | Out-Null
    Add-MpPreference -ExclusionPath $toolsDir

    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/EventLog-Baseline-Guide/main/bat/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait
    #endregion

    #region Sysmon Installation
    $sysmonDir = Join-Path $toolsDir "Sysmon"
    New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null

    $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
    $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
    Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
    Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force

    $sysmonConfigUri = "https://raw.githubusercontent.com/smashtitle/sysmon-modular/master/sysmonconfig-research.xml"
    $sysmonConfigXml = Join-Path $sysmonDir "sysmonconfig-research.xml"
    Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml

    $sysmonExe = Join-Path $sysmonDir "Sysmon64.exe"
    # Note: The original script was missing the sysmon config file argument. This has been added.
    Start-Process -FilePath $sysmonExe -ArgumentList "-accepteula", "-i", $sysmonConfigXml -Wait
    #endregion

    #region Winlogbeat Installation
    Write-Host "Installing Winlogbeat..."
    $winlogbeatDir = "C:\Program Files\Winlogbeat" # Standard installation path
    $winlogbeatZipUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.14.1-windows-x86_64.zip"
    $winlogbeatZipPath = Join-Path $tempDir "Winlogbeat.zip"

    Invoke-WebRequest -Uri $winlogbeatZipUri -OutFile $winlogbeatZipPath
    Expand-Archive -Path $winlogbeatZipPath -DestinationPath $tempDir -Force
    
    # The archive extracts into a versioned folder, so we find it and move the contents
    $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like 'winlogbeat-*' } | Select-Object -First 1
    Move-Item -Path (Join-Path $extractedDir.FullName "*") -Destination $winlogbeatDir -Force
    
    # Set location to the Winlogbeat directory and run the installation script
    Set-Location -Path $winlogbeatDir
    PowerShell.exe -ExecutionPolicy Bypass -File .\install-service-winlogbeat.ps1
    
    Write-Host "Winlogbeat service installed."
    #endregion
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
