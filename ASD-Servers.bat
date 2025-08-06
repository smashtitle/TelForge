wevtutil sl Security /ms:8589934592
wevtutil sl System /ms:268435456
wevtutil sl Application /ms:268435456
wevtutil sl "Microsoft-Windows-PowerShell/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-RPC-Events/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-WMI-Activity/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-TaskScheduler/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-SMBServer/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-SMBServer/Security" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-SMBClient/Security" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-LSA/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-CAPI2/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-NTLM/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-PrintService/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-PrintService/Admin" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-CodeIntegrity/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-GroupPolicy/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-WinRM/Operational" /enabled:true /retention:false  /maxsize:268435456
wevtutil sl "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-Diagnosis-Scripted/Operational" /enabled:true /retention:false /maxsize:268435456
wevtutil sl "Microsoft-Windows-Sysmon/Operational" /enabled:true /retention:false /maxsize:268435456

:: Enable PowerShell Module logging
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging /v EnableModuleLogging /t REG_DWORD /d 1 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames /v 1 /t REG_SZ /d * /f

:: Enable PowerShell Script Block logging
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f

:: E

::
:: Configure Security log
:: Note: subcategory IDs are used instead of the names in order to work in any OS language.

:: Account Logon
:::: Credential Validation
auditpol /set /subcategory:{0CCE923F-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Kerberos Authentication Service (disable for clients)
auditpol /set /subcategory:{0CCE9242-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Kerberos Service Ticket Operations (disable for clients)
auditpol /set /subcategory:{0CCE9240-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: Account Management
:::: Computer Account Management
auditpol /set /subcategory:{0CCE9236-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Other Account Management Events
auditpol /set /subcategory:{0CCE923A-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Security Group Management
auditpol /set /subcategory:{0CCE9237-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: User Account Management
auditpol /set /subcategory:{0CCE9235-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: Detailed Tracking
:::: Plug and Play
auditpol /set /subcategory:{0cce9248-69ae-11d9-bed3-505054503030} /success:enable /failure:enable
:::: Process Creation
auditpol /set /subcategory:{0CCE922B-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Enable command line auditing (Detailed Tracking)
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit /v ProcessCreationIncludeCmdLine_Enabled /f /t REG_DWORD /d 1
:::: Process Termination (default: disabled)
auditpol /set /subcategory:{0CCE922C-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: RPC Events
:: auditpol /set /subcategory:{0CCE922E-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Audit Token Right Adjustments (default: disabled)
auditpol /set /subcategory:{0CCE924A-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: DS Access
:::: Directory Service Access (disable for clients)
auditpol /set /subcategory:{0CCE923B-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Directory Service Changes (disable for clients)
auditpol /set /subcategory:{0CCE923C-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: Logon/Logoff
:::: Account Lockout
auditpol /set /subcategory:{0CCE9217-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Group Membership (disabled due to noise)
auditpol /set /subcategory:{0CCE9249-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Logoff
auditpol /set /subcategory:{0CCE9216-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Logon
auditpol /set /subcategory:{0CCE9215-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Network Policy Server (currently disabled while testing)
:: auditpol /set /subcategory:{0CCE9243-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Other Logon/Logoff Events
auditpol /set /subcategory:{0CCE921C-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Special Logon
auditpol /set /subcategory:{0CCE921B-69AE-11D9-BED3-505054503030} /success:enable /failure:disable

:: Object Access
:::: Application Generated (currently disabled while testing)
:: auditpol /set /subcategory:{0CCE9222-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Certification Services (disable for client OSes)
auditpol /set /subcategory:{0CCE9221-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Detailed File Share (disabled due to noise)
auditpol /set /subcategory:{0CCE9244-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: File Share (disable if too noisy)
auditpol /set /subcategory:{0CCE9224-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: File System (disabled due to noise)
auditpol /set /subcategory:{0CCE921D-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Filtering Platform Connection (disable if too noisy)
auditpol /set /subcategory:{0CCE9226-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Filtering Platform Packet Drop (disabled due to noise)
auditpol /set /subcategory:{0CCE9225-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Kernel Object (disabled due to noise)
auditpol /set /subcategory:{0CCE921F-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Other Object Access Events
auditpol /set /subcategory:{0CCE9227-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Registry (currently disabled due to noise)
auditpol /set /subcategory:{0CCE921E-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Removable Storage
:: auditpol /set /subcategory:{0CCE9245-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: SAM
auditpol /set /subcategory:{0CCE9220-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: Policy Change
:::: Audit Policy Change
auditpol /set /subcategory:{0CCE922F-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Authentication Policy Change
auditpol /set /subcategory:{0CCE9230-69AE-11D9-BED3-505054503030} /success:enable /failure:disable
:::: Authorization Policy Change (currently disabled while testing)
:: auditpol /set /subcategory:{0CCE9231-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Filtering Platform Policy Change (currently disabled while testing)
:: auditpol /set /subcategory:{0CCE9233-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: MPSSVC Rule-Level Policy Change (currently disabled while testing)
:: auditpol /set /subcategory:{0CCE9232-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Other Policy Change Events
auditpol /set /subcategory:{0CCE9234-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: Privilege Use
:::: Sensitive Privilege Use (disable if too noisy)
auditpol /set /subcategory:{0CCE9228-69AE-11D9-BED3-505054503030} /success:enable /failure:enable

:: System
:::: IPsec Driver
auditpol /set /subcategory:{0CCE9213-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Other System Events (needs testing)
:: auditpol /set /subcategory:{0CCE9214-69AE-11D9-BED3-505054503030} /success:disable /failure:enable
:::: Security State Change
auditpol /set /subcategory:{0CCE9210-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: Security System Extension
auditpol /set /subcategory:{0CCE9211-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
:::: System Integrity
auditpol /set /subcategory:{0CCE9212-69AE-11D9-BED3-505054503030} /success:enable /failure:enable
