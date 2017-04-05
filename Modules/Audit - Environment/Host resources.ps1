Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VMHost | ForEach-Object {

    [pscustomobject]@{

        Host     = $_.name
        Model    = "$($_.Manufacturer) $($_.Model)"
        Processor= "$($_.ExtensionData.Hardware.CpuInfo.NumCpuPackages) X $($_.ProcessorType)"
        pCores   = $_.numcpu
        HT       = $_.HyperthreadingActive
        CpuGHz   = [math]::round($_.cputotalmhz/1kb,2)
        CpuUsage = "$([math]::round($_.CpuUsageMhz / $_.CpuTotalMhz * 100,1)) %"
        "vCpu:Core"= "$([math]::round(($Vm | where vmhost -eq $_ | where powerstate -eq poweredon | Measure-Object -Property numcpu -Sum).sum / ($_.numcpu),2)):1"
        MemoryGB = [math]::round($_.MemoryTotalGB,0)
        MemoryUsage = "$([math]::round($_.MemoryUsageGB / $_.MemoryTotalGB * 100,1)) %"
        NICs     = $_.ExtensionData.Summary.Hardware.NumNics
        Uptime   = (get-date) - ($_.ExtensionData.Runtime.BootTime) | ForEach-Object { "$($_.days) days $($_.hours) hours"}

    }

} | Sort-Object host


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

$CriticalState = $false
$WarningState  = $false
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