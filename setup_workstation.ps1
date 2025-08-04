param(
    [Parameter(Mandatory=$true)]
    [string]$logstashIp
)

# Set script to terminate on any error
$ErrorActionPreference = 'Stop'

# Define core directories and add a Defender exclusion for the main tools folder
$toolsDir = "C:\Tools"
$tempDir  = "C:\Tools\Temp"
New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir  -ItemType Directory -Force | Out-Null
Write-Host "[*] Adding Microsoft Defender exclusion for $toolsDir to prevent interference."
Add-MpPreference -ExclusionPath $toolsDir

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
$winlogbeatVersion = '9.1.0'
$winlogbeatSvcName = "winlogbeat"
# FIX: Define $installPath outside the conditional block to ensure it's always available.
$installPath = "C:\Program Files\Winlogbeat" # Note: Elastic changes the path structure. This is a more stable default.
$winlogbeatExePath = Join-Path $installPath "winlogbeat.exe"


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

        if (-not $rpcFwInstaller) {
            throw "Could not find RpcFwManager.exe in the extracted archive."
        }

        Start-Process -FilePath $rpcFwInstaller -ArgumentList "/install" -Wait
        Write-Host "[+] RPC Firewall installed successfully."
    }

    if (Get-Service -Name $sysmonSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] Sysmon is already installed. Re-applying configuration..."
        # IMPROVEMENT: Re-apply the configuration in case it has changed.
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml -UseBasicParsing
        $sysmonArgs = @('-c', $sysmonConfigXml)
        Start-Process -FilePath $sysmonExe -ArgumentList $sysmonArgs -Wait
        Write-Host "[+] Sysmon configuration updated."
    } else {
        Write-Host "[*] Installing Sysmon..."
        New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null
        
        $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
        $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
        
        Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
        Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force
        
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml
        
        # IMPROVEMENT: Use an array for arguments to avoid quoting issues.
        $sysmonArgs = @('-accepteula', '-i', $sysmonConfigXml)
        Start-Process -FilePath $sysmonExe -ArgumentList $sysmonArgs -Wait
        Write-Host "[+] Sysmon installed successfully."
    }

    Write-Host "--- Installing and Configuring Winlogbeat ---"

    # FIX: Add the Defender exclusion for the Winlogbeat path unconditionally.
    Write-Host "[*] Adding Microsoft Defender exclusion for $installPath."
    Add-MpPreference -ExclusionPath $installPath

    if (-not (Test-Path $winlogbeatExePath)) {
        Write-Host "[*] Winlogbeat not found. Installing..."
        # Note: The original script used an MSI, but the ZIP provides more control and is more common in automated setups.
        # This approach uses the ZIP distribution.
        $winlogbeatZipName = "winlogbeat-$winlogbeatVersion-windows-x86_64.zip"
        $downloadUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$winlogbeatZipName"
        $zipPath     = Join-Path $tempDir $winlogbeatZipName
        
        Write-Host "[*] Downloading Winlogbeat $winlogbeatVersion ZIP..."
        Invoke-WebRequest -Uri $downloadUri -OutFile $zipPath

        Write-Host "[*] Extracting and installing Winlogbeat..."
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        $extractedDir = Join-Path $tempDir "winlogbeat-$winlogbeatVersion-windows-x86_64"
        Copy-Item -Path $extractedDir -Destination $installPath -Recurse -Force
        
        # Run the installation script provided by Elastic
        PowerShell.exe -ExecutionPolicy Bypass -File (Join-Path $installPath "install-service-winlogbeat.ps1")
        Write-Host "[+] Winlogbeat service installed successfully."
    } else {
        Write-Host "[*] Winlogbeat is already installed. Stopping service to update configuration."
        Stop-Service -Name $winlogbeatSvcName -Force
    }

    Write-Host "[*] Configuring winlogbeat.yml with Logstash IP: $logstashIp"
    # FIX: Correct the path to the template file relative to the script's location.
    $localConfigPath = Join-Path $PSScriptRoot "winlogbeat.yml"
    if (-not (Test-Path $localConfigPath)) {
        throw "The required configuration template 'winlogbeat.yml' was not found at '$localConfigPath'."
    }

    # FIX: Use the always-defined $installPath variable.
    $destConfigPath = Join-Path $installPath "winlogbeat.yml"
    (Get-Content $localConfigPath -Raw) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content -Path $destConfigPath -Force
    Write-Host "[+] Configuration applied to $destConfigPath"

    Write-Host "[*] Starting Winlogbeat service..."
    Start-Service -Name $winlogbeatSvcName
    Write-Host "[+] Winlogbeat service started."
}
catch {
    Write-Error "An error occurred during setup: $($_.Exception.Message)"
    # Exit with a non-zero code to signal failure in automation pipelines
    exit 1
}

Write-Host "--- Workstation setup complete. ---"
