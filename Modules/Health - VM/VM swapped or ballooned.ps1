Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################

# If required declare variables and thresholds here.


# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VM | Where-Object {($_.ExtensionData.Summary.QuickStats.BalloonedMemory -ne "0") -or ($_.ExtensionData.Summary.QuickStats.SwappedMemory -ne "0")} | ForEach-Object {

    [pscustomobject]@{

        # Properties of the ouptut object
        VM        = $_.name
        Host      = $_.vmhost
        Memory    = "$($_.memoryMB) MB"
        Swapped   = "$($_.ExtensionData.Summary.QuickStats.SwappedMemory) MB"
        Ballooned = "$($_.ExtensionData.Summary.QuickStats.BalloonedMemory) MB"
        
    }

} | Sort-Object VM


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
# Appending metadata to output object
######################
# No edit here

IF ($CriticalState) {$Importance = "critical"} ELSEIF ($WarningState) {$Importance = "warning"} ELSE {$Importance = "information"}
IF (!$NumberLinesDisplay) {$NumberLinesDisplay = [int]::MaxValue}

$Output | select *,
    @{l="Importance";e={$Importance}},
    @{l="NumberLinesDisplay";e={$NumberLinesDisplay}}