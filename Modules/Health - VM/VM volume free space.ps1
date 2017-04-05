Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run
######################
# Declare variables and thresholds here.

$VMFREEPC = 10

# Place the output object into the output variable.

$Output = $VM | ForEach-Object {

    $curVM = $_

    $_.Guest.Disks | select @{l="VM";e={$curVM.name}},
        Path,
        @{l="CapacityGB";e={[math]::Round($_.CapacityGB,2)}},
        @{l="FreeGB";e={[math]::Round($_.FreeSpaceGB,2)}},
        @{l="FreePercent";e={[math]::Round(($_.FreeSpace / $_.Capacity * 100),1)}}

} | Where-Object {$_.freePercent -le $VMFREEPC} | Sort-Object FreePercent


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

$CriticalState = $Output | Where-Object {$_.freePercent -le 5}
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