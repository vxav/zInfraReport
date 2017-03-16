Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.

$RDYThreshold = 10

Function ConvertTo-RDYPercent {

<#

.DESCRIPTION
    - RDYms are the ms reported by the host
    - intervalSec is the update intervals for the performance charts in seconds (defaults below)
        + Realtime: 20 seconds
        + Past Day: 5 minutes (300 seconds)
        + Past Week: 30 minutes (1800 seconds)
        + Past Month: 2 hours (7200 seconds)
        + Past Year: 1 day (86400 seconds)

#>

 param(
    [Parameter(Mandatory = $True,ValueFromPipeline=$True)]
    [int]$RDYms,
    [int]$intervalSec
)

        $RDYpercent=($RDYms/($intervalSec*1000))*100
        [math]::round($RDYpercent,1)
    
}

# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VM | where powerstate -eq poweredon | ForEach-Object{
    
    IF ($_.ExtensionData.Config.CpuAllocation.Limit = -1) {$CPUlimit = $false} ELSE {$CPUlimit = $_.ExtensionData.Config.CpuAllocation.Limit}
    
    [pscustomobject]@{
        VM          = $_.Name
        'RDY%'      = $_ | get-stat -Stat cpu.ready.summation -IntervalMins 5 | Measure-Object -Property value -Average | select -ExpandProperty average | ConvertTo-RDYPercent -intervalSec 300
        'GHz limit' = $CPUlimit
    }

} | Where-Object {$_.'RDY%' -gt $RDYThreshold}


######################
# Declare object importance and number of lines to display.
######################
# Write a condition that should trigger each state based on the output object
# If the event should always be critical or warning, set the relevant variable to $true. Otherwise set them to $false.
# If nothing is specified, the event is treated as information
# Example for a datastore space usage:
    # $CriticalState = $output | where-object {$_.freePercent -lt 10 -or $_.Provisionned -gt 200}
    # $WarningState  = $output | where-object {$_.freePercent -lt 20 -or $_.Provisionned -gt 150}
# Lines to display will display only this number of records but reports the total number of records. leave false to display all records.

$CriticalState = $Output | Where-Object {$_.'RDY%' -gt 20}
$WarningState  = $true
$NumberLinesDisplay = $false


######################
# Appending metadata to output object.
######################
# No edit here.

IF ($CriticalState) {$Importance = "critical"} ELSEIF ($WarningState) {$Importance = "warning"} ELSE {$Importance = "information"}
IF (!$NumberLinesDisplay) {$NumberLinesDisplay = [int]::MaxValue}

$Output | select *,
    @{l="Importance";e={$Importance}},
    @{l="NumberLinesDisplay";e={$NumberLinesDisplay}}