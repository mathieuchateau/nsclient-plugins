# ====================================================================
# Check time against DC or specified server through NRPE / w32tm
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
	[string]$refTimeServer,
	[int]$maxWarn = 1,
	[int]$maxError = 5
)

$output=""
$exitcode=2
$random=
if(($refTimeServer -eq $null) -or ($refTimeServer -eq "") -or ($refTimeServer -eq " "))
{
	$refTimeServer=$env:LOGONSERVER -replace ('\\',"")
	if(($refTimeServer -match "^$|^ $") -or ($env:LOGONSERVER -match $refTimeServer))
	{
		if((gwmi win32_computersystem).partofdomain -eq $true)
		{
			#Must use select and not .Name directly. If some DC are down, command will be empty with .Name
			$fromAD=(([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() | % { $_.DomainControllers }))| select Name 
			foreach ($entry in $fromAD)
			{
				if(($env:COMPUTERNAME -match $entry) -or ($entry -match $env:COMPUTERNAME))
				{
					#this server is a DC, can't check time against itself
					$fromAD.Remove($entry)
				}
			}
			if($fromAD.Count -gt 1)
			{
				#get a random DC from AD, as no server provided and no logon server could be found
				$refTimeServer=(Get-Random -InputObject $fromAD).Name
			}
			else
			{
				#only one DC, defaulting to internet
				$refTimeServer="pool.ntp.org"
			}
		}
		else
		{
			#Workgroup but no server to check time against provided. Defaulting to internet to do something
			$refTimeServer="pool.ntp.org"
		}
	}
}

if(($refTimeServer -eq $null) -or ($refTimeServer -eq "") -or ($refTimeServer -eq " "))
{
	#Something bad happened. Should never happen
	Write-Host "CRITICAL: can't auto detect logon server to check against. Need to specify manually using refTimeServer argument"
	exit 2
}


$temp=w32tm /stripchart /computer:$refTimeServer /period:1 /dataonly /samples:1
$temp=($temp | select -Last 1) -replace (".*, ","")
$temp=$temp -replace ("s$","")


if ($temp -match "^(\+|\-)[0-9]+\.[0-9]+$")
{
	$output=$temp+"s - checked against "+$refTimeServer
	if ([math]::abs($temp) -gt $maxError)
	{
		$state="CRITICAL"
		$exitcode=2
	}
	elseif ([math]::abs($temp) -gt $maxWarn)
	{
		$state="WARNING"
		$exitcode=1
	}
	else
	{
		$state="OK"
		$exitcode=0
	}
}
else
{
	$output="Error: - used $refTimeServer as time server - output:$temp"
	$exitcode=2
}

$output=$state+":"+$output+$random+'|'+"offset="+$temp+"s"+";"+$maxWarn+";"+$maxError+";"
Write-Host $output
exit $exitcode
