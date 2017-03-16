Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# If required declare variables and thresholds here.


# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VMhost | ForEach-Object {

    $curHost = $_

    $CommitedMem = (($VM | where powerstate -eq pweredon | where vmhost -eq $curHost).ExtensionData.Summary.config.MemorySizeMB | Measure-Object -Sum).sum / 1024

    IF ($CommitedMem -gt $curHost.MemoryTotalGB) {

        [pscustomobject]@{

            Host = $curHost.name
            "Host memory" = [string][math]::Round($curHost.MemoryTotalGB,0) + " GB"
            "Provisioned memory" = [string][math]::Round($CommitedMem,0) + " GB"

        }

    }

}


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

$CriticalState = $true
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