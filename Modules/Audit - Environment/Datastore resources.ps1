Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $datastore | ForEach-Object {
    
    $curDS = $_

    [pscustomobject]@{

        Name          = $_.name
        LiveVM        = $VM | Where-Object {($_.ID -replace "VirtualMachine-","") -in $curDS.ExtensionData.vm.value} | where powerstate -eq poweredon | Measure-Object | select -ExpandProperty count
        CapacityGB    = [math]::round($_.capacityGB,2)
        FreeGB        = [math]::round($_.FreeSpaceGB,2)
        FreeSpace     = "$([math]::round($_.FreeSpaceGB / $_.capacityGB * 100,2)) %"
        ProvisionedGB = [Math]::Round((($_.extensiondata.summary.capacity - $_.extensiondata.summary.FreeSpace + $_.extensiondata.summary.Uncommitted) / 1GB),2)
        LunBacking    = IF ($_.type -eq "vmfs") {$_.ExtensionData.Info.Vmfs.Extent.diskname} ELSEIF ($_.type -eq "nfs") {$_.RemotePath} ELSE {"Unknown"}
        MountPath     = $_.ExtensionData.Host[0].Mountinfo.path
        Type          = IF ($_.type -eq "vmfs") {"$($_.type) $($_.FileSystemVersion)"} ELSE {$_.type}
        IsLocal       = IF ($_.type -eq "vmfs") {$_.ExtensionData.Info.Vmfs.Local} ELSE {""}
        Ssd           = IF ($_.type -eq "vmfs") {$_.ExtensionData.Info.Vmfs.SSD} ELSE {""}

    }

} | Sort-Object name


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