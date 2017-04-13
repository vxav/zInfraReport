Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = 


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

# If the AppendToLatestReport variable is set to true, the content gathered in this report will be prepended to the previous one instead of replacing it.
# The global report will still be sorted by sets. If the sort order was Date it will still be ok. If it was by name it could turn into something like " a,b,c,d,a,b,c,d,a,b,c,d".
# To make it right the output variable would need to be re-sorted before sending back to the main script.

$PrependToLatestReport = $false

######################
# Appending metadata to output object.
######################
# No edit here.

IF ($CriticalState) {$Importance = "critical"} ELSEIF ($WarningState) {$Importance = "warning"} ELSE {$Importance = "information"}
IF (!$NumberLinesDisplay) {$NumberLinesDisplay = [int]::MaxValue}

IF ($PrependToLatestReport) {
    
    $FolderCSV = ".\Metadata\PermanentReporting\$($DefaultVIserver.name)"
    IF (!(test-path $FolderCSV)) {New-Item -ItemType Directory $FolderCSV | out-null}
    $PrependCSV = "$FolderCSV\$($MyInvocation.MyCommand.Name).csv"
    
    IF (Test-Path $PrependCSV) {$LatestReport = Import-Csv $PrependCSV}

    $Output | Export-Csv $PrependCSV

    IF ($LatestReport) {
        $LatestReport | Export-Csv $PrependCSV -Append
        $Output = Import-Csv $PrependCSV
    }
    
}

$Output | select *,
    @{l="Importance";e={$Importance}},
    @{l="NumberLinesDisplay";e={$NumberLinesDisplay}}