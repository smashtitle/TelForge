param(
    [Parameter(Mandatory=$true)]
    [string]$logstashIp
)

$ErrorActionPreference = 'Stop'

try {
    $toolsDir = "C:\Tools"
    $tempDir = Join-Path $toolsDir "Temp"
    $winlogbeatDir = Join-Path $toolsDir "Winlogbeat"
    New-Item -Path $toolsDir, $tempDir, $winlogbeatDir -ItemType Directory -Force | Out-Null
    Add-MpPreference -ExclusionPath $toolsDir, $winlogbeatDir
    Write-Host "[+] Directories created and excluded from Defender."

    $rpcFwZipUri = "https://github.com/zeronetworks/rpcfirewall/releases/download/v2.2.5/RPCFW_2.2.5.zip"
    $rpcFwZipPath = Join-Path $tempDir "RPCFW.zip"
    Invoke-WebRequest -Uri $rpcFwZipUri -OutFile $rpcFwZipPath
    Expand-Archive -Path $rpcFwZipPath -DestinationPath $tempDir -Force
    $rpcFwInstaller = Get-ChildItem -Path $tempDir -Filter "RpcFwManager.exe" -Recurse | Select-Object -First 1
    Start-Process -FilePath $rpcFwInstaller.FullName -ArgumentList "/install" -Wait
    Write-Host "[+] RPC Firewall installed."

    $winlogbeatExe = Join-Path $winlogbeatDir "winlogbeat.exe"
    if (-not (Test-Path $winlogbeatExe)) {
        $winlogbeatZipUri = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-9.1.0-windows-x86_64.zip"
        $winlogbeatZip = Join-Path $tempDir "winlogbeat.zip"
        Invoke-WebRequest -Uri $winlogbeatZipUri -OutFile $winlogbeatZip
        Expand-Archive -Path $winlogbeatZip -DestinationPath $tempDir -Force
        $extractedDir = Get-ChildItem -Path $tempDir -Directory -Filter "winlogbeat-*" | Select-Object -First 1
        Move-Item -Path ($extractedDir.FullName + "\*") -Destination $winlogbeatDir -Force
        Remove-Item $extractedDir -Recurse -Force
        Write-Host "[+] Winlogbeat downloaded and installed."
    }

    $winlogbeatConfigYml = Join-Path $winlogbeatDir "winlogbeat.yml"
    $winlogbeatConfigUrl = "https://github.com/smashtitle/TelForge/raw/refs/heads/main/winlogbeat.yml"
    Invoke-WebRequest -Uri $winlogbeatConfigUrl -OutFile $winlogbeatConfigYml -UseBasicParsing
    (Get-Content $winlogbeatConfigYml -Raw) -replace '<LOGSTASH_VM_DNS_NAME>', $logstashIp | Set-Content -Path $winlogbeatConfigYml -Force
    Write-Host "[+] Configuration file created."

    Start-Process -FilePath $winlogbeatExe -ArgumentList "-c `"$winlogbeatConfigYml`""
    Write-Host "[+] Winlogbeat started."
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}

Write-Host "Log forwarding completed. "
