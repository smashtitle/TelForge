$tempPath = "$env:TEMP\"
iwr -Uri "https://raw.githubusercontent.com/oloruntolaallbert/public/refs/heads/main/ConfigureWinRM.ps1" -OutFile "$tempPath`ConfigureWinRM.ps1"
powershell -ExecutionPolicy Bypass -File "$tempPath`ConfigureWinRM.ps1"

iwr -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-9.0.3-windows-x86_64.zip" -OutFile "$tempPath`winlogbeat-9.0.3-windows-x86_64.zip"
Expand-Archive -Path "$tempPath`winlogbeat-9.0.3-windows-x86_64.zip" -DestinationPath "C:\\Tools"
Set-Content -Path ""$tempPath`winlogbeat-9.0.3-windows-x86_64.zip" 