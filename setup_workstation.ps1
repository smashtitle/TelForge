param(
    [Parameter(Mandatory=$true)]
    [string]$logstashIp
)

# Disable Microsoft Defender for the setup process
Set-MpPreference -PUAProtection Disabled
Set-MpPreference -DisableRealtimeMonitoring $true

# Set script to terminate on any error
$ErrorActionPreference = 'Stop'

# --- Core Directories and Defender Exclusions ---
$toolsDir        = "C:\Tools"
$tempDir         = Join-Path $toolsDir "Temp"
$winlogbeatDir   = Join-Path $toolsDir "Winlogbeat"
New-Item -Path $toolsDir      -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir       -ItemType Directory -Force | Out-Null
New-Item -Path $winlogbeatDir -ItemType Directory -Force | Out-Null

Write-Host "[*] Adding Microsoft Defender exclusions..."
Add-MpPreference -ExclusionPath $toolsDir
Add-MpPreference -ExclusionPath $tempDir
Add-MpPreference -ExclusionPath $winlogbeatDir

# --- Variable Definitions ---
# Sysmon
$sysmonDir       = Join-Path $toolsDir "Sysmon"
$sysmonExe       = Join-Path $sysmonDir "Sysmon64.exe"
$sysmonConfigUri = "https://raw.githubusercontent.com/smashtitle/sysmon-modular/master/sysmonconfig-research.xml"
$sysmonConfigXml = Join-Path $sysmonDir "sysmonconfig-research.xml"
$sysmonSvcName   = "Sysmon64"

# RPC Firewall
$rpcFwSvcName = "RPCFW"

# Winlogbeat
$winlogbeatVersion   = '9.1.0'
$winlogbeatExePath   = Join-Path $winlogbeatDir "winlogbeat.exe"
$winlogbeatConfigYml = Join-Path $winlogbeatDir "winlogbeat.yml"

try {
    Write-Host "--- Installing Prerequisite Log Sources ---"

    Write-Host "[*] Applying Advanced Security Audit event log baseline..."
    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/EventLog-Baseline-Guide/main/bat/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait
    Write-Host "[+] Baseline applied successfully."

    if (Get-Service -Name $rpcFwSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] RPC Firewall is already installed. Skipping."
    } else {
        Write-Host "[*] Installing RPC Firewall..."
        $rpcFwZipUri = "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip"
        $rpcFwZipPath = Join-Path $tempDir "RPCFW.zip"
        $rpcFwExtractPath = Join-Path $tempDir "RPCFW_Extracted"
        
        Invoke-WebRequest -Uri $rpcFwZipUri -OutFile $rpcFwZipPath
        Expand-Archive -Path $rpcFwZipPath -DestinationPath $rpcFwExtractPath -Force
        $rpcFwInstaller = Get-ChildItem -Path $rpcFwExtractPath -Filter "RpcFwManager.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        if (-not $rpcFwInstaller) { throw "Could not find RpcFwManager.exe in the extracted archive." }

        Start-Process -FilePath $rpcFwInstaller -ArgumentList "/install" -Wait
        Write-Host "[+] RPC Firewall installed successfully."
    }

    if (Get-Service -Name $sysmonSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] Sysmon is already installed. Re-applying configuration..."
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml -UseBasicParsing
        Start-Process -FilePath $sysmonExe -ArgumentList @('-c', $sysmonConfigXml) -Wait
        Write-Host "[+] Sysmon configuration updated."
    } else {
        Write-Host "[*] Installing Sysmon..."
        New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null
        $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
        $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
        
        Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
        Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml
        
        Start-Process -FilePath $sysmonExe -ArgumentList @('-accepteula', '-i', $sysmonConfigXml) -Wait
        Write-Host "[+] Sysmon installed successfully."
    }

    Write-Host "--- Installing and Configuring Winlogbeat ---"

    if (-not (Test-Path $winlogbeatExePath)) {
        Write-Host "[*] Winlogbeat not found. Downloading and extracting..."
        $winlogbeatZipName = "winlogbeat-$winlogbeatVersion-windows-x86_64.zip"
        $downloadUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$winlogbeatZipName"
        $zipPath     = Join-Path $tempDir $winlogbeatZipName
        
        Invoke-WebRequest -Uri $downloadUri -OutFile $zipPath
        
        $extractTemp = Join-Path $tempDir "winlogbeat-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractTemp -Force

        # Find the single directory created by the extraction
        $sourceDir = Get-ChildItem -Path $extractTemp | Select-Object -First 1

        # If the target directory already exists, remove it to ensure a clean move
        if (Test-Path $winlogbeatDir) {
            Remove-Item $winlogbeatDir -Recurse -Force
        }

        # Move the entire extracted directory to the target path
        Move-Item -Path $sourceDir.FullName -Destination $winlogbeatDir -Force

        # Clean up the temporary extraction parent folder
        Remove-Item $extractTemp -Recurse -Force

        Write-Host "[+] Winlogbeat moved to $winlogbeatDir"
    } else {
        Write-Host "[*] Winlogbeat already exists in $winlogbeatDir. Skipping download."
    }

    Write-Host "[*] Configuring winlogbeat.yml with Logstash IP: $logstashIp"
    $localConfigTemplate = Join-Path $PSScriptRoot "winlogbeat.yml"
    if (-not (Test-Path $localConfigTemplate)) {
        throw "The required configuration template 'winlogbeat.yml' was not found at '$localConfigTemplate'."
    }
    (Get-Content $localConfigTemplate -Raw) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content -Path $winlogbeatConfigYml -Force
    Write-Host "[+] Configuration applied to $winlogbeatConfigYml"

    Write-Host "[*] Launching Winlogbeat..."
    $arguments = @("-c", "`"$winlogbeatConfigYml`"")
    Start-Process -FilePath $winlogbeatExePath -ArgumentList $arguments
    Write-Host "[+] Winlogbeat process started."

}
catch {
    Write-Error "An error occurred during setup: $($_.Exception.Message)"
    # Exit with a non-zero code to signal failure in automation pipelines
    exit 1
}

Write-Host "--- Workstation setup complete. ---"
