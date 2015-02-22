# ====================================================================
# Check SharePoint 2010/2013 state
# Author: Mathieu Chateau - LOTP
# mail: mathieu.chateau@lotp.fr
# version 0.1
# ====================================================================

#
# Require Set-ExecutionPolicy RemoteSigned.. or sign this script with your PKI 
#

# ============================================================
#
#  Do not change anything behind that line!
#
param 
(
	[bool]$refreshHealth=$true,
	[bool]$refreshBPA=$true,
	[bool]$useBPA=$true,
	[int]$maxWarn = 1,
	[int]$maxError = 5
	
)

# check that powershell Hyper-V module is present
if(Get-PSSnapin -Registered -Name "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue)
{
	try
	{
		Add-PSSnapin "Microsoft.SharePoint.Powershell"
		import-module -Name BestPractices
	}
	catch
	{
		Write-Host "CRITICAL: Missing PowerShell SharePoint snapin"
		exit 2
	}
}
else
{
	Write-Host "CRITICAL: Missing PowerShell SharePoint snapin"
	exit 2
}
$output=""
# check params if provided
if($refreshHealth)
{
	Get-SPTimerJob | Where {$_.Name -like "*Health*" -and $_.Name -like "*-all-*"}| Start-SPTimerJob
}
if($refreshBPA)
{
	Start-Job -Name "Refresh BPA" -ScriptBlock { get-bpaModel | Invoke-BpaModel} |Out-Null
}
$spHealth=[Microsoft.SharePoint.Administration.Health.SPHealthReportsList]::Local.Items |
   Select-Object @{ Label= "Title"; Expression= { $_["Title"]} },
   @{ Label= "HealthRuleType"; Expression= { $_["HealthRuleType"] } }, 
   @{ Label= "HealthReportSeverity"; Expression= { $_["HealthReportSeverity"] } },
   @{ Label= "HealthReportCategory"; Expression= { $_["HealthReportCategory"] } },
   @{ Label= "HealthReportExplanation"; Expression= { $_["HealthReportExplanation"] } }
   
$spWarning=($spHealth| ? {$_.HealthReportSeverity -match "^2.*"}).Title
$spError=($spHealth| ? {$_.HealthReportSeverity -match "^1.*"}).Title
$spInfo= ($spHealth| ? {$_.HealthReportSeverity -match "^3.*"}).Title  

if(($spError.Count -gt $maxError))
{
	$state="CRITICAL"
	$exitcode=2
}
elseif(($spWarning.Count -gt $maxWarn))
{
	$state="WARNING"
	$exitcode=1
}
else
{
	$state="OK"
	$exitcode=0
}

$output=$state+": "+"SP Error:"+$spError.Count+" "+"SP Warning:"+$spWarning.Count
if($useBPA)
{
	$bpaResult=Get-BpaResult -ModelId Microsoft/Windows/Hyper-V -ErrorAction 'silentlycontinue' | ? {$_.Resolution -ne $null}
	$countBPAWarn=($bpaResult |? {$_.Severity -eq "Warning"}).Count
	$countBPACrit=($bpaResult |? {$_.Severity -eq "Error"}).Count
	$output+=" "+"BPA Error:"+$countBPACrit+" "+"BPA Warning:"+$countBPAWarn
}
$output+="|"+"'SP Error'="+$spError.Count+";"+$maxWarn+";"+$maxError+";0;65535 "
$output+="'SP Warning'="+$spWarning.Count+";"+$maxWarn+";"+$maxError+";0;65535 "
if($useBPA)
{
	$output+="'BPA Error'="+$countBPACrit+";"+$maxWarn+";"+$maxError+";0;65535 "
	$output+="'BPA Warning'="+$countBPAWarn+";"+$maxWarn+";"+$maxError+";0;65535"
}
Write-Host $output
exit $exitcode
