<#
.SYNOPSIS
    Move and archive files according to a CSV file

.DESCRIPTION
    Copy and move file depending of instructions contained in the specified CSV file
    CSV required headers:
    "SourceFolder";"DestinationFolder";"FilePattern";"ArchiveFolder";"ShouldTimestampArchivedFolder";"DeleteEmptyFile";MailAdressesOnSuccess";"MailAdressesOnFailure"

    If no ArchiveFolder is specified move files corresponding to FilePattern from SourceFolder to DestinationFolder
    If an ArchiveFolder is specified first copy files correspoding to FilePattern from SourceFolder to DestinationFolder
    then if the copy was successfull, move files from SourceFolder to:
    - ArchiveFolder if ShouldTimestampArchivedFolder is false
    - a subfolder ArchiveFolder\ddMMyyyy (created if needed) if ShouldTimestampArchivedFolder is true

.PARAMETER Target
    Name or IP Address to test against

.PARAMETER Port
    TCP Port number to test against

.INPUTS
    This script take no inputs

.OUTPUTS
    This script generate Nagios/Centreon compatible output

.EXAMPLE
    .\check_tcp_port.ps1 -target www.lotp.fr -Port 80

.LINK
    No link currently available

.NOTES
    Version :    v0.1
    Author  :    Mathieu Chateau

#>

#Requires -Version 3.0
#
# Require Set-ExecutionPolicy RemoteSigned.. or sign this script with your PKI 
#
[CmdletBinding()]
param (
    [Parameter()]
    [string]$Target=$(throw "Target is mandatory, please provide a value."),
    [int]$Port=$(throw "Port is mandatory, please provide a value."),
    [int]$WarningThreshold=50,
    [int]$criticalThreshold=100
)
$ErrorActionPreference = "Stop"

#uncomment to enable debug mode
#$DebugPreference = "Continue"

# ============================================================
#
#  Do not change anything behind that line!
#

$Global:exitcode=0
$output=@()
$performance=@()
$majorError=$false

function RaiseAlert ([int]$code)
{
	if($Global:exitcode -lt [int]$code)
	{
		$Global:exitcode=$code
		Write-Debug "Raising exitcode from $Global:exitcode to $code"
	}
}

if(($args[0] -eq "") -or ($args.length -lt 1))
{
	#$output+="Error: this script need hostname and port to test"
	#RaiseAlert 2
	#$majorError=$true
}
try
{
	if($majorError -eq $false)
	{
        try 
        {
            #Partially based on https://stackoverflow.com/questions/9506056/is-it-possible-to-force-powershell-script-to-throw-if-a-required-parameter-is-om
            $ip = [System.Net.Dns]::GetHostAddresses($Target) | select-object IPAddressToString -expandproperty  IPAddressToString
            if($ip.GetType().Name -eq "Object[]")
            {
                $ip = $ip[0]
            }
            $tcpClient = New-Object Net.Sockets.TcpClient
            $tcpClient.Nodelay=$true
            $tcpClient.SendTimeout=$criticalThreshold+1
            $tcpClient.ReceiveTimeout=$criticalThreshold+1
            $timeSpan= [TimeSpan]::FromMilliseconds($criticalThreshold+1)
            $result=$tcpClient.BeginConnect($ip,$Port,$null,$null)
            $tcpPerformance=Measure-Command {$success = $result.AsyncWaitHandle.WaitOne($timeSpan)}
            if($success -and $tcpClient.Connected)
            {
                if($tcpPerformance.Milliseconds -gt $criticalThreshold)
                {
                    RaiseAlert 2
                }
                elseif ($tcpPerformance.Milliseconds -gt $WarningThreshold)
                {
                    RaiseAlert 1
                }
                $output+="Connection to $target port $Port in $($tcpPerformance.Milliseconds)ms"
            }
            else
            {
                RaiseAlert 2
                $output+="Connection failed to $target port $Port"
            }
        } 
        catch 
        {
            RaiseAlert 2
            $output+="Unable to resolve $Target"
        }
        finally
        {
            $tcpClient.Dispose()
        }
        
	}
    $performance+="'"+"Connection Time in ms"+"'"+"="+$tcpPerformance.Milliseconds+";"+$WarningThreshold+";"+$criticalThreshold+" "

}
catch
{
	$exitcode=2
	$majorError=$true
	$output+="CRITICAL - unknown error: $_"
}


if($exitcode -eq 0){$state="OK"}
if($exitcode -eq 1){$state="WARNING"}
if($exitcode -eq 2){$state="CRITICAL"}
Write-Host $state" - "$output"|"$performance
exit $exitcode
