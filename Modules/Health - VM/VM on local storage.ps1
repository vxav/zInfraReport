Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# If required declare variables and thresholds here.


# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $Datastore | Where-Object {$_.type -eq "vmfs" -and $_.ExtensionData.Info.Vmfs.Local -eq $true} | ForEach-Object {

    $curDS = $_

    $curDS | get-VM | Where-Object {$_.ExtensionData.Layout.Disk.diskfile -like "*$($curDS.name)*"} | 
        select @{l="VM";e={$_.name}},
            @{l="Datastore";e={$curDS.name}},
            @{l="Disk";e={[string]($_ | Get-Harddisk | Where-Object {$_.filename -like "*$($curDS.name)*"} | ForEach-Object {"$($_.Name) ($($_.CapacityGB)GB)"})}} 

} | Sort-Object Datastore


######################
# Declare object importance and number of lines to display.
######################
# Write a condition that should trigger each state based on the output object
# If the event should always be critical or warning, set the relevant variable to $true
# If nothing is specified, the event is treated as information
# Example for a datastore space usage:
    # $CriticalState = $output | where-object {$_.freePercent -lt 10 -or $_.Provisionned -gt 200}
    # $WarningState  = $output | where-object {$_.freePercent -lt 20 -or $_.Provisionned -gt 150}
# Lines to display will display only this number of records but reports the total number of records. Comment it to display all records.

$CriticalState = $false
$WarningState  = $false
$NumberLinesDisplay = 10


######################
# Appending metadata to output object.
######################
# No edit here.

IF ($CriticalState) {$Importance = "critical"} ELSEIF ($WarningState) {$Importance = "warning"} ELSE {$Importance = "information"}
IF (!$NumberLinesDisplay) {$NumberLinesDisplay = [int]::MaxValue}

$Output | select *,
    @{l="Importance";e={$Importance}},
    @{l="NumberLinesDisplay";e={$NumberLinesDisplay}}