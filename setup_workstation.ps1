# Disable Defender settings, enable event providers, install Sysmon
$ErrorActionPreference = 'Stop'

try {
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
    Start-Process -FilePath $sysmonExe -ArgumentList "-accepteula", "-i" -Wait
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
