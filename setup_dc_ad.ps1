# Unattended AD DS installer + DC promotion (MOF-less DSC, RunOnce resume)
$DomainName     = 'telforge.internal'
$NetBIOSName    = 'TEL'
$DSRM_Plaintext = 'P@GM#CNq$BGNtrc%!xyz908234h'
$CreateWorkstationsOU = $true

$NupkgUrl   = 'https://github.com/dsccommunity/ActiveDirectoryDsc/releases/download/v6.7.0/ActiveDirectoryDsc.6.7.0.nupkg'
$ModuleName = 'ActiveDirectoryDsc'
$ModuleVer  = '6.7.0'
$phase2Arg  = '-Phase2'
$scriptPath = $MyInvocation.MyCommand.Path
$SetupDir   = 'C:\ADSetup'
$RunOnceKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$ModuleRoot = 'C:\Program Files\WindowsPowerShell\Modules'
$ModuleDest = Join-Path $ModuleRoot "$ModuleName\$ModuleVer"

if (-not (Test-Path $SetupDir)) { New-Item -ItemType Directory -Path $SetupDir -Force | Out-Null }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Ensure-ActiveDirectoryDsc {
    if (Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.Version -ge [version]$ModuleVer }) { return }
    $tmp = Join-Path $env:TEMP "ADDSC_$([guid]::NewGuid().ToString('N'))"
    $nupkg = Join-Path $tmp 'mod.nupkg'
    $unz   = Join-Path $tmp 'unzipped'
    New-Item -ItemType Directory -Path $tmp,$unz -Force | Out-Null
    Invoke-WebRequest -Uri $NupkgUrl -OutFile $nupkg -UseBasicParsing
    Expand-Archive -Path $nupkg -DestinationPath $unz -Force
    $manifest = Get-ChildItem -Path $unz -Filter "$ModuleName.psd1" -Recurse | Select-Object -First 1
    if (-not $manifest) { throw "Module manifest not found" }
    if (-not (Test-Path $ModuleDest)) { New-Item -ItemType Directory -Path $ModuleDest -Force | Out-Null }
    Copy-Item -Path (Join-Path $manifest.DirectoryName '*') -Destination $ModuleDest -Recurse -Force
    Import-Module $ModuleName -Force
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($args -contains $phase2Arg) {
    if ($CreateWorkstationsOU) {
        Import-Module ActiveDirectory -ErrorAction Stop
        $dn = 'DC=' + ($DomainName -split '\.' -join ',DC=')
        if (-not (Get-ADOrganizationalUnit -LDAPFilter '(name=Workstations)' -SearchBase $dn -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name 'Workstations' -Path $dn -ErrorAction Stop | Out-Null
        }
    }
    exit 0
}

try {
    Ensure-ActiveDirectoryDsc
    Invoke-DscResource -ModuleName PSDesiredStateConfiguration -Name WindowsFeature -Method Set `
        -Property @{ Name='AD-Domain-Services'; Ensure='Present' } -ErrorAction Stop -Verbose:$false

    if (-not $DSRM_Plaintext) { throw "DSRM password not set" }
    $dsrmSecure = ConvertTo-SecureString $DSRM_Plaintext -AsPlainText -Force
    $adminCred  = New-Object System.Management.Automation.PSCredential("$NetBIOSName\Administrator",$dsrmSecure)

    $result = Invoke-DscResource -ModuleName $ModuleName -Name ADDomain -Method Set `
        -Property @{
            DomainName=$DomainName
            DomainNetbiosName=$NetBIOSName
            SafemodeAdministratorPassword=$dsrmSecure
            DomainAdministratorCredential=$adminCred
            DatabasePath='C:\Windows\NTDS'
            LogPath='C:\Windows\NTDS'
            SysvolPath='C:\Windows\SYSVOL'
        } -ErrorAction Stop -Verbose:$false

    if (-not (Test-Path $RunOnceKey)) { New-Item -Path $RunOnceKey -Force | Out-Null }
    $runOnceCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $phase2Arg"
    New-ItemProperty -Path $RunOnceKey -Name "Continue-AD-Setup" -Value $runOnceCmd -PropertyType String -Force | Out-Null

    if ($result -and $result.RebootRequired) {
        Restart-Computer -Force
    } else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath $phase2Arg
    }
} catch {
    $_.Exception.Message | Out-File "$SetupDir\error.log" -Append
    exit 1
}