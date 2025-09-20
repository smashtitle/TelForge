# # Enhanced ConfigureWinRM.ps1
# # Configure WinRM for Azure Attack Range

# Write-Host "Starting WinRM configuration for Azure Attack Range..."

# try {
#     # Set PowerShell Execution Policy first
#     Write-Host "Configuring PowerShell Execution Policy..."
#     Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
#     Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
#     Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
#     Write-Host "PowerShell Execution Policy set to Bypass"

#     # Enable PowerShell Remoting
#     Write-Host "Enabling PowerShell Remoting..."
#     Enable-PSRemoting -Force

#     # Configure WinRM
#     Write-Host "Configuring WinRM service..."
#     winrm quickconfig -q

#     # Set WinRM service to automatic startup
#     Set-Service -Name WinRM -StartupType Automatic
    
#     # Configure WinRM settings for Azure Attack Range
#     Write-Host "Applying WinRM configuration settings..."
#     winrm set winrm/config/service '@{AllowUnencrypted="true"}'
#     winrm set winrm/config/service/auth '@{Basic="true"}'
#     winrm set winrm/config/client/auth '@{Basic="true"}'
#     winrm set winrm/config/client '@{TrustedHosts="*"}'
    
#     # Configure WinRM timeouts for long-running attack simulations
#     winrm set winrm/config/service '@{MaxTimeoutms="7200000"}'
#     winrm set winrm/config/shell '@{MaxShellsPerUser="30"}'
#     winrm set winrm/config/shell '@{MaxProcessesPerShell="25"}'
#     winrm set winrm/config/shell '@{MaxMemoryPerShellMB="1024"}'

#     # Configure Windows Firewall rules
#     Write-Host "Configuring firewall rules..."
#     New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
#     New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

#     # Restart WinRM service to apply all changes
#     Write-Host "Restarting WinRM service..."
#     Restart-Service WinRM -Force

#     # Test WinRM configuration
#     Write-Host "Testing WinRM configuration..."
#     $winrmConfig = winrm get winrm/config
#     Write-Host "WinRM Configuration applied successfully"

#     # Create a marker file to indicate successful configuration
#     $markerPath = "C:\Windows\Temp\WinRM_Configured.txt"
#     Set-Content -Path $markerPath -Value "WinRM configured successfully at $(Get-Date)"
#     Write-Host "Configuration marker created at: $markerPath"

#     Write-Host "WinRM configuration completed successfully for Azure Attack Range!"
    
# } catch {
#     Write-Error "Error during WinRM configuration: $_"
#     exit 1
# }















# ConfigureWinRM.ps1
$ErrorActionPreference = "Stop"

Write-Output "Starting WinRM configuration..."

# Set network profile to private for all connections
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Configure WinRM
Write-Output "Configuring WinRM..."
Enable-PSRemoting -Force -SkipNetworkProfileCheck
winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Configure firewall
Write-Output "Configuring firewall rules..."
$ruleName = "WinRM-HTTP-In-TCP"
$existingRule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Remove-NetFirewallRule -Name $ruleName
}

New-NetFirewallRule -Name $ruleName `
    -DisplayName "Windows Remote Management (HTTP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5985 `
    -Action Allow

Write-Output "WinRM configuration completed successfully"
