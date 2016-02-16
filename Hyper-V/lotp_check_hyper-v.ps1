# ====================================================================
# Check Hyper-V VM state
# Author: Mathieu Chateau - LOTP
# mail: mathieu.chateau@lotp.fr
# version 0.2
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
	[string]$excludeVM = "",
	[int]$maxWarn = 1,
	[int]$maxCrit = 5
)


Function Using-Culture (
[System.Globalization.CultureInfo]$culture,
[ScriptBlock]$script)
{
    $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    trap
    {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
    }
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
    $ExecutionContext.InvokeCommand.InvokeScript($script)
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
} # End Function

# check that powershell Hyper-V module is present
if(Get-Module -Name "Hyper-V" -ListAvailable)
{
	try
	{
		Import-Module -Name Hyper-V
		import-module -Name BestPractices
	}
	catch
	{
		Write-Host "CRITICAL: Missing PowerShell Hyper-V module"
		exit 2
	}
}
else
{
	Write-Host "CRITICAL: Missing PowerShell Hyper-V module"
	exit 2
}
$countVMNotRunning=0
$countVMIssue=0
$allVM=get-VM
$output=""
$excludeVMArray=@()
# check params if provided
if($excludeVM -ne ""
{
	$excludeVMArray=$excludeVM -split ","
}
Using-Culture en-us {
    foreach ($vm in $allVM)
    {
	    if ($excludeVMArray -notcontains $vm.Name)
	    {
		    if($vm.State -ne [Microsoft.HyperV.PowerShell.VMState].GetEnumName(2))
		    {
			    $countVMNotRunning++
		    }
		    if($vm.Status -ne "Operating normally")
		    {
			    $countVMIssue++
		    }
	    }
    }

    $bpaResult=Get-BpaResult -ModelId Microsoft/Windows/Hyper-V -ErrorAction 'silentlycontinue' | ? {$_.Resolution -ne $null}
    Start-Job -Name "Refresh BPA" -ScriptBlock { Invoke-BpaModel -ModelId Microsoft/Windows/Hyper-V} |Out-Null

    $countBPAWarn=($bpaResult |? {$_.Severity -eq "Warning"}).Count
    $countBPACrit=($bpaResult |? {$_.Severity -eq "Error"}).Count

    if(($countBPACrit -gt $maxCrit) -or ($countVMNotRunning -gt $maxCrit) -or ($countVMIssue -gt $maxCrit))
    {
	    $state="CRITICAL"
	    $exitcode=2
    }
    elseif(($countBPAWarn -gt $maxWarn) -or ($countVMNotRunning -gt $maxWarn) -or ($countVMIssue -gt $maxWarn))
    {
	    $state="WARNING"
	    $exitcode=1
    }
    else
    {
	    $state="OK"
	    $exitcode=0
    }

    $output=$state+": "+"'VM Not Running:'"+$countVMNotRunning+" "+"'VM issues:'"+$countVMIssue+" "+"BPA Error:"+$countBPACrit+" "+"BPA Warning:"+$countBPAWarn
    $output+="|"+"VM_Not_Running="+$countVMNotRunning+" "
    $output+="VM_issues="+$countVMIssue+" "
    $output+="BPA_Error="+$countBPACrit+" "
    $output+="BPA_Warning="+$countBPAWarn

    Write-Host $output
    exit $exitcode
}