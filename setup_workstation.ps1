param(
    [Parameter(Mandatory=$true)]
    [string]$logstashIp
)

$ErrorActionPreference = 'Stop'

$toolsDir = "C:\Tools"
$tempDir  = Join-Path $env:TEMP "setup-$($PID)"

$sysmonDir = Join-Path $toolsDir "Sysmon"
$sysmonExe = Join-Path $sysmonDir "Sysmon64.exe"
$sysmonConfigUri = "https://raw.githubusercontent.com/smashtitle/sysmon-modular/master/sysmonconfig-research.xml"
$sysmonConfigXml = Join-Path $sysmonDir "sysmonconfig-research.xml"
$sysmonSvcName = "Sysmon64"

$rpcFwDir = Join-Path $toolsDir "RPCFW"
$rpcFwSvcName = "RPCFW"

$winlogbeatVersion = '9.1.0'
$winlogbeatDir     = "C:\Program Files\Winlogbeat"
$winlogbeatSvcName = "winlogbeat"

# Check for Administrator privileges
Write-Host "Checking for Administrator privileges..."
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to run this script. Please re-run from an elevated PowerShell prompt."
    exit 1
}
Write-Host "Administrator check passed."

# Create temporary and tools directories if they don't exist
New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir  -ItemType Directory -Force | Out-Null


# --- Main Execution Block ---
try {
    # --- 2. Install Prerequisite Log Sources ---
    Write-Host "--- Installing Prerequisite Log Sources ---"

    # Apply ASD Event Log Baseline
    Write-Host "[*] Applying Advanced Security Audit event log baseline..."
    $baselineBatUri = "https://raw.githubusercontent.com/smashtitle/EventLog-Baseline-Guide/main/bat/ASD-Servers.bat"
    $baselineBatPath = Join-Path $tempDir "ASD-Servers.bat"
    Invoke-WebRequest -Uri $baselineBatUri -OutFile $baselineBatPath
    Start-Process -FilePath $baselineBatPath -Wait
    Write-Host "[+] Baseline applied successfully."

    # Install RPC Firewall
    if (Get-Service -Name $rpcFwSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] RPC Firewall service is already installed. Skipping."
    } else {
        Write-Host "[*] Installing RPC Firewall..."
        $rpcFwZipUri = "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip"
        $rpcFwZipPath = Join-Path $tempDir "RPCFW.zip"
        $rpcFwExtractPath = Join-Path $tempDir "RPCFW_Extracted"
        
        Invoke-WebRequest -Uri $rpcFwZipUri -OutFile $rpcFwZipPath
        Expand-Archive -Path $rpcFwZipPath -DestinationPath $rpcFwExtractPath -Force
        
        $rpcFwInstaller = Join-Path $rpcFwExtractPath "RPCFW_2.2.5\RpcFwManager.exe"
        Start-Process -FilePath $rpcFwInstaller -ArgumentList "/install" -Wait
        Write-Host "[+] RPC Firewall installed successfully."
    }

    # Install Sysmon
    if (Get-Service -Name $sysmonSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] Sysmon service is already installed. Skipping."
    } else {
        Write-Host "[*] Installing Sysmon..."
        New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null
        
        $sysmonZipUri = "https://download.sysinternals.com/files/Sysmon.zip"
        $sysmonZipPath = Join-Path $tempDir "Sysmon.zip"
        
        Invoke-WebRequest -Uri $sysmonZipUri -OutFile $sysmonZipPath
        Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force
        
        Invoke-WebRequest -Uri $sysmonConfigUri -OutFile $sysmonConfigXml
        
        Start-Process -FilePath $sysmonExe -ArgumentList "-accepteula -i `"$sysmonConfigXml`"" -Wait
        Write-Host "[+] Sysmon installed successfully."
    }

    # --- 3. Install and Configure Winlogbeat ---
    Write-Host "--- Installing and Configuring Winlogbeat ---"

    if (Get-Service -Name $winlogbeatSvcName -ErrorAction SilentlyContinue) {
        Write-Host "[*] Winlogbeat service is already installed. Ensuring it is started."
        Start-Service -Name $winlogbeatSvcName
    } else {
        Write-Host "[*] Downloading Winlogbeat $winlogbeatVersion..."
        $archiveName = "winlogbeat-$winlogbeatVersion-windows-x86_64.zip"
        $downloadUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$archiveName"
        $archivePath = Join-Path $tempDir $archiveName
        
        Invoke-WebRequest -Uri $downloadUri -OutFile $archivePath

        Write-Host "[*] Extracting Winlogbeat archive..."
        $extractPath = Join-Path $tempDir "winlogbeat-extracted"
        Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force
        
        $sourceDir = Join-Path $extractPath "winlogbeat-$winlogbeatVersion-windows-x86_64"

        # The winlogbeat.yml file should be in the same directory as this script.
        $localConfigPath = Join-Path $PSScriptRoot "winlogbeat.yml"
        if (-not (Test-Path $localConfigPath)) {
            throw "winlogbeat.yml not found in script directory: $PSScriptRoot"
        }
        
        $destConfigPath = Join-Path $sourceDir "winlogbeat.yml"
        Copy-Item -Path $localConfigPath -Destination $destConfigPath -Force

        Write-Host "[*] Configuring winlogbeat.yml with Logstash IP: $logstashIp"
        # Use a unique placeholder in your winlogbeat.yml template, e.g., __LOGSTASH_IP__
        (Get-Content $destConfigPath -Raw) -replace '__LOGSTASH_IP__', $logstashIp | Set-Content $destConfigPath

        Write-Host "[*] Copying Winlogbeat files to '$winlogbeatDir'..."
        Copy-Item -Path "$sourceDir\*" -Destination $winlogbeatDir -Recurse -Force

        Write-Host "[*] Installing Winlogbeat service..."
        Push-Location $winlogbeatDir
        # This is the correct way to call the installer script.
        # The original script had this line and another call, which was redundant.
        powershell.exe -ExecutionPolicy Unrestricted -File ".\install-service-winlogbeat.ps1"
        Pop-Location
        
        Write-Host "[+] Winlogbeat service installed successfully."
    }

    Write-Host "[*] Starting Winlogbeat service..."
    Start-Service -Name $winlogbeatSvcName
    Write-Host "[+] Winlogbeat service started."

}
catch {
    Write-Error "An error occurred during setup: $($_.Exception.Message)"
    # You can add more detailed error logging here if needed.
}
finally {
    # --- 4. Cleanup ---
    Write-Host "--- Cleaning up temporary files ---"
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
        Write-Host "[+] Temporary directory removed."
    }
}
