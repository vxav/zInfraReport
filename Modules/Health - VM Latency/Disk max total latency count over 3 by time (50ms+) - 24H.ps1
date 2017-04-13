Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.

$latencyThreshold = 50

# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $Latencies24H | where value -gt $latencyThreshold | Group-Object -Property Timestamp | where count -gt 2 | ForEach-Object {

    [pscustomobject]@{

        Time = Get-date "$($_.Name)" -format u
        VM = $_.count
        AverageLatency = "$([math]::round(($_.group | Measure-Object -Property Value -Average | select -ExpandProperty average),0)) ms"
        MaxLatency = "$($_.group | Measure-Object -Property Value -Maximum | select -ExpandProperty maximum) ms"

    }

} | Sort-Object Time -Descending


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