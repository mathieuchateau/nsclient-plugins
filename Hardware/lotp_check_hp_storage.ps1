# ====================================================================
# Check HP storage health state
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
	[string]$hpacucli = $env:ProgramFiles+"\Compaq\Hpacucli\Bin\hpacucli.exe"
)

$output=""
$global:errorLevel=0
$countController=0
$countArray=0
$countLogicalDrive=0
$countPhysicalDrive=0

function RaiseErrorLevel([int] $level)
{
    if($global:errorLevel -lt $level)
    {
        $global:errorLevel=$level
    }
}

if((Test-Path -Path $hpacucli) -eq $true)
{
    try
    {
        $data=. "$hpacucli" "ctrl all show config detail"
    }
    catch
    {
        $output+="error executing $hpacucli : $_"
        RaiseErrorLevel 2
    }
    foreach ($line in $data)
    {
        if($line -match "in Slot ")
            {
                $current=$line -split(":")[0]
                $countController++
            }
            if($line -match "Array:")
            {
                $current=$line -split(":")[0]
                $countArray++
            }
            if($line -match "Logical Drive:")
            {
                $current=$line -split(":")[0]
                $countLogicalDrive++
            }
            if($line -match "physicaldrive ")
            {
                $current=$line -split(":")[0]
                $countPhysicalDrive++
            }
        if($line -match "Status")
        {
            
            $temp=$line -split(":")
            if($temp[1] -match "Predictive failure")
            {
                $output+="$current - $line"
                RaiseErrorLevel 1
            }
            elseif($temp[1] -notmatch "OK|Initialization Completed|Disabled")
            {
                $output+="$current - $line"
                RaiseErrorLevel 2
            }
        }
    }
}
else
{
    $output+="missing file $hpacucli"
    RaiseErrorLevel 3
}

$perf="Controllers=$countController ;Array=$countArray ; logicalDrive=$countLogicalDrive ; physicalDrives=$countPhysicalDrive"
if($global:errorLevel -eq 3)
{
	$state="UNKNOWN"
	$exitcode=3
}
elseif($global:errorLevel -eq 2)
{
	$state="CRITICAL"
	$exitcode=2
}
elseif($global:errorLevel -eq 1)
{
	$state="WARNING"
	$exitcode=1
}
else
{
	$state="OK"
	$exitcode=0
    $output=$perf
}
$finalOutput=$state+": "+$output + "|" + $perf

Write-Host $finalOutput
exit $exitcode
