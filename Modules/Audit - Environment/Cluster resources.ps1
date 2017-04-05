Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $cluster | ForEach-Object {
    
    $totalmem = [math]::round($_.ExtensionData.Summary.TotalMemory/1gb,2)
    $totalcpu = [math]::round($_.ExtensionData.Summary.TotalCpu/1000,2)
    $memusage = [math]::round(($vmhost | Measure-Object -Property MemoryUsageGB -sum).sum,2)
    $cpuusage = [math]::round(($vmhost | Measure-Object -Property cpuusagemhz -sum).sum / 1000,2)

    [pscustomobject]@{

        Name = $_.name
        DRSEnabled = $_.DRSEnabled
        HAEnabled = $_.HAEnabled
        EVCmode = $_.ExtensionData.Summary.CurrentEVCModeKey
        TotalCpuGHz = $totalcpu
        CpuUsageGhz = $cpuusage
        CpuUsage    = "$([math]::round($cpuusage / $totalcpu * 100,2)) %"
        TotalMemoryGB = $totalmem
        MemoryUsageGB = $memusage
        MemoryUsage = "$([math]::round($memusage / $totalmem * 100,2)) %"
        StorageGB = $datastore | Measure-Object -Property CapacityGB -Sum | select -ExpandProperty sum
        StorageUsageGB = [math]::round(($datastore | Measure-Object -Property CapacityGB -Sum | select -ExpandProperty sum)  -  ($datastore | Measure-Object -Property FreeSpaceGB -Sum | select -ExpandProperty sum),2)
        StorageUsage = "$([math]::Round((1 - (($datastore | Measure-Object -Property FreeSpaceGB -Sum | select -ExpandProperty sum) / ($datastore | Measure-Object -Property CapacityGB -Sum | select -ExpandProperty sum))) * 100,2)) %"
        LiveVM      = ($VM | where powerstate -eq poweredon).count
        TotalVM     = $vm.count

    }

} | sort-object  name


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