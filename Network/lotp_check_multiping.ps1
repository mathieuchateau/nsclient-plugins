# ====================================================================
# Ping a list of targets through NRPE / w32tm
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
	[string]$targets,
	[int]$maxWarn = 1,
	[int]$maxError = 5
)

$output=""
$exitcode=2
$countOK=0
$countKO=0
$targetsArray=@()
$targetsArray=$targets -split(' ')
Remove-Job -Name * -Confirm:$false -Force
foreach($t in $targetsArray)
{
	Start-Job -Name $t -ArgumentList $t -ScriptBlock {param($t);if(Test-Connection -ComputerName $t  -Count 2 -Quiet -ErrorAction SilentlyContinue){return $true}else{return $false}} |Out-Null
}
while(Get-Job -State Running)
{
	Start-Sleep -Milliseconds 500
}
foreach ($job in Get-Job)
{
	$temp=Receive-Job -Name $job.Name
	if($temp)
	{
		$countOK++
	}
	else
	{
		$countKO++
		$output+=$job.Name+" - "
	}
}
if ($countKO -gt $maxError)
{
	$state="CRITICAL"
	$exitcode=2
}
elseif ($countKO -gt $maxWarn)
{
	$state="WARNING"
	$exitcode=1
}
else
{
	$state="OK"
	$exitcode=0
}

$output=$state+":"+$countOK+" online"+" - "+$countKO+" offline - "+$output
$output+='|'
$output+="online="+$countOK+";"+$maxWarn+";"+$maxError+";"+" "
$output+="offline="+$countKO+";"+$maxWarn+";"+$maxError+";"
Write-Host $output
exit $exitcode
