Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# If required declare variables and thresholds here.

$VCPURATIO = 5

# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VMHost | ForEach-Object {

    $vCPUperpCPU = [math]::round(($VM | where vmhost -eq $_ | where powerstate -eq poweredon | Measure-Object -Property numcpu -Sum).sum / ($_.ExtensionData.Summary.Hardware.NumCpuCores),2)

    IF ($vCPUperpCPU -gt $VCPURATIO) {

        [pscustomobject]@{
            Host = $_.name
            "vCPU density" = "$vCPUperpCPU :1"
        }

    }
} | Sort-Object "vCPU density"


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

$CriticalState = $output | where-object {[int]($_.'vCPU density' -split " :")[0] -gt 10}
$WarningState  = $output | where-object {[int]($_.'vCPU density' -split " :")[0] -gt 5}
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