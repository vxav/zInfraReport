Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################

# If required declare variables and thresholds here.

$OlderThanDays = 15

# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VM | where name -NotLike *_replica | ForEach-Object {

    $CurVM = $_

    $_ | Get-Snapshot | ForEach-Object {

    [pscustomobject]@{

        # Output properties
        VM = $_.VM
        Created = get-date $_.Created -format u
        Name = $_.name
        Description = $_.description
        SizeGB = [math]::Round($_.SizeGB,2)
        IsCurrent = $_.iscurrent
        PowerState = $CurVM.PowerState

    }

    }
} | Where-Object {$_.Created -lt (get-date).AddDays(-$OlderThanDays)} | Sort-Object Created -Descending

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
$WarningState  = $true
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