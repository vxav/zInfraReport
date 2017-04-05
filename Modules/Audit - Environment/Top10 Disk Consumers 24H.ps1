Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.

$TOPx = 10



# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VM | where powerstate -eq poweredon | ForEach-Object {

    $W_KBPS = Get-Stat -Stat virtualdisk.write.average -Entity ($_) -IntervalMins 5 | Where-Object {!$_.instance} | 
        Measure-Object -Property Value -Average | select -ExpandProperty average

    $R_KBPS = Get-Stat -Stat virtualdisk.read.average -Entity ($_) -IntervalMins 5 | Where-Object {!$_.instance} | 
        Measure-Object -Property Value -Average | select -ExpandProperty average

    [pscustomobject]@{

        VM = $_.name
        "Average Kbps" = [math]::round($W_KBPS + $R_KBPS,0)
        "Read %"    = [math]::round($R_KBPS / ($W_KBPS + $R_KBPS) * 100,0)
        "Write %"   = [math]::round($W_KBPS / ($W_KBPS + $R_KBPS) * 100,0)

    }

} | Sort-Object "Average Kbps" -Descending | select -First $TOPx


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