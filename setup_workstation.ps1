$tempPath = "$env:TEMP\"
iwr -Uri "https://raw.githubusercontent.com/oloruntolaallbert/public/refs/heads/main/ConfigureWinRM.ps1" -OutFile "$tempPath`ConfigureWinRM.ps1"
powershell -ExecutionPolicy Bypass -File "$tempPath`ConfigureWinRM.ps1"

iwr -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-9.0.3-windows-x86_64.zip" -OutFile "$tempPath`winlogbeat-9.0.3-windows-x86_64.zip"
Expand-Archive -Path "$tempPath`winlogbeat-9.0.3-windows-x86_64.zip" -DestinationPath "C:\\Tools"

iwr -Uri "https://raw.githubusercontent.com/smashtitle/TelForge/main/winlogbeat.yml" -OutFile "$tempPath`winlogbeat.yml"
Copy-Item -Path "$tempPath`winlogbeat.yml" -Destination "C:\\Tools\\winlogbeat-9.0.3-windows-x86_64\winlogbeat.yml" -Force
