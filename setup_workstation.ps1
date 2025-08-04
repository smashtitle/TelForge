param(
    [Parameter(Mandatory=$true)]
    [string]$logstashIp
)

# --- Script Configuration ---
# Stop script on any terminating error.
$ErrorActionPreference = 'Stop'

# Define paths and tool configurations.
$toolsDir = "C:\Tools"
$tempDir  = "C:\Tools\Temp"

# Sysmon configuration.
$sysmonDir       = Join-Path $toolsDir "Sysmon"
$sysmonExe       = Join-Path $sysmonDir "Sysmon64.exe"
$sysmonConfigUri = "https://raw.githubusercontent.com/smashtitle/sysmon-modular/master/sysmonconfig-research.xml"
$sysmonConfigXml = Join-Path $sysmonDir "sysmonconfig-research.xml"
$sysmonSvcName   = "Sysmon64"

# RPC Firewall configuration.
$rpcFwSvcName = "RPCFW"

# Winlogbeat configuration.
$winlogbeatVersion = '9.1.0'
$winlogbeatSvcName = "winlogbeat"

# Create temporary and tools directories.
New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir  -ItemType Directory -Force | Out-Null
Add-MpPreference -ExclusionPath $toolsDir

# --- Main Execution Block ---
try {
    Write-Host "[*] Adding temporary Microsoft Defender exclusion for $toolsDir to prevent interference."

    # --- 2. Install Prerequisite Log Sources ---
    Write-Host "--- Installing Prerequisite Log Sources ---"

    # Apply ASD Event Log Baseline.
    Write-Host "[*] Applying Advanced Security Audit event log baseline..."
    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/EventLog-Baseline-Guide/main/bat/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait
    Write-Host "[+] Baseline applied successfully."

    # Install RPC Firewall.
    if (Get-Service -Name $rpcFwSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] RPC Firewall is already installed. Skipping."
    } else {
        Write-Host "[*] Installing RPC Firewall..."
        $rpcFwZipUri = "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip"
        $rpcFwZipPath = Join-Path $tempDir "RPCFW.zip"
        $rpcFwExtractPath = Join-Path $tempDir "RPCFW_Extracted"
        
        Invoke-WebRequest -Uri $rpcFwZipUri -OutFile $rpcFwZipPath
        Expand-Archive -Path $rpcFwZipPath -DestinationPath $rpcFwExtractPath -Force
        
        # Dynamically find the installer executable within the extracted files.
        $rpcFwInstaller = Get-ChildItem -Path $rpcFwExtractPath -Filter "RpcFwManager.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName

        if (-not $rpcFwInstaller) {
            throw "Could not find RpcFwManager.exe in the extracted archive."
        }

        Start-Process -FilePath $rpcFwInstaller -ArgumentList "/install" -Wait
        Write-Host "[+] RPC Firewall installed successfully."
    }

    # Install Sysmon.
    if (Get-Service -Name $sysmonSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] Sysmon is already installed. Skipping."
    } else {
        Write-Host "[*] Installing Sysmon..."
        New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null
        
        $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
        $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
        
        Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
        Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force
        
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml
        
        $sysmonArgs = "-accepteula -i `"$sysmonConfigXml`""
        Start-Process -FilePath $sysmonExe -ArgumentList $sysmonArgs -Wait
        Write-Host "[+] Sysmon installed successfully."
    }

    # --- 3. Install and Configure Winlogbeat ---
    Write-Host "--- Installing and Configuring Winlogbeat ---"

    if (-not (Get-Service -Name $winlogbeatSvcName -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Winlogbeat not found. Installing..."
        $msiName     = "winlogbeat-$winlogbeatVersion-windows-x86_64.msi"
        $downloadUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$msiName"
        $msiPath     = Join-Path $tempDir $msiName
        
        $installPath = "C:\Program Files\Elastic\Beats\$winlogbeatVersion\winlogbeat"
        Add-MpPreference -ExclusionPath $installPath
        Write-Host "[+] Using known Winlogbeat path: $installPath"

        Write-Host "[*] Downloading Winlogbeat $winlogbeatVersion MSI..."
        Invoke-WebRequest -Uri $downloadUri -OutFile $msiPath

        Write-Host "[*] Installing Winlogbeat service via MSI..."
        $msiArgs = "/i `"$msiPath`" /qn"

        Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait
        Write-Host "[+] Winlogbeat service installed successfully."
    } else {
        Write-Host "[*] Winlogbeat is already installed. Stopping service to update configuration."
        Stop-Service -Name $winlogbeatSvcName -Force
    }
    
    if (-not (Test-Path $installPath)) {
        throw "The expected Winlogbeat directory was not found at '$installPath'."
    }

    # Configure winlogbeat.yml
    Write-Host "[*] Configuring winlogbeat.yml with Logstash IP: $logstashIp"
    $localConfigPath = Join-Path $PSScriptRoot "winlogbeat.yml"
    if (-not (Test-Path $localConfigPath)) {
        throw "The required configuration template 'winlogbeat.yml' was not found alongside the script."
    }

    $destConfigPath = Join-Path $installPath "winlogbeat.yml"
    (Get-Content $localConfigPath -Raw) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content -Path $destConfigPath -Force
    Write-Host "[+] Configuration applied to $destConfigPath"

    # Start the Winlogbeat service.
    Write-Host "[*] Starting Winlogbeat service..."
    Start-Service -Name $winlogbeatSvcName
    Write-Host "[+] Winlogbeat service started."
}
catch {
    Write-Error "An error occurred during setup: $($_.Exception.Message)"
}

Write-Host "--- Workstation setup complete. ---"
