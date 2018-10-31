# nsclient-plugins
plugins for nsclient (nagios monitoring)

nsclient is a free daemon to monitor Windows Server from nagios through nrpe, as many others usages.

The key is that nsclient allow then PowerShell, vbscript & co to be executed on Windows and then report result to nagios/centreon.

Powershell Policy should be set to Remotesigned or you will have to sign all scripts:
Set-ExecutionPolicy RemoteSigned

They should be added as wrapped scripts in nsclient.ini:

[/settings/external scripts]  
allow arguments = true  
allow nasty characters = true  
script path =   
timeout = 60  

[/settings/external scripts/wrapped scripts]  
check_updates=check_updates.vbs $ARG1$ $ARG2$  
check_ad_account=lotp_check_ad_accounts.ps1 $ARG1$ $ARG2$ $ARG3$ $ARG4$ $ARG5$  
check_hyper-v=lotp_check_hyper-v.ps1 $ARG1$ $ARG2$ $ARG3$  
check_sharepoint=lotp_check_sharepoint.ps1 $ARG1$ $ARG2$ $ARG3$ $ARG4$ $ARG5$  
check_certificate=lotp_check_certificate.ps1 -checkMyStore $ARG1$ -checkRootStore $ARG2$ -checkCAStore $ARG3$   -checkAuthRootStore $ARG4$ -checkSharePointStore $ARG5$ -expireInDays $ARG6$ -maxWarn $ARG7$ -maxError $ARG8$  
check_time=lotp_check_time.ps1 -refTimeServer $ARG1$ -maxWarn $ARG2$ -maxError $ARG3$  
check_multiping=lotp_check_multiping.ps1 -targets $ARG1$ -maxWarn $ARG2$ -maxError $ARG3$  
check_windows_updates=check_windows_updates.ps1
check_tcp_port=lotp_check_tcp_port.ps1 -Target $ARG1$ -Port $ARG2$ -WarningThreshold $ARG3$ -criticalThreshold $ARG4$

