Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# If required declare variables and thresholds here.
$DatastoreLowPercent = 20
$DatastoreTooManyVM = 16
$DatastoreHighProvPercent = 150

# Place the output object into the output variable.
# Sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $Datastore | ForEach-Object {
    
    $CapacityGB    = [Math]::Round($_.capacitygb,2)
    $FreeGB        = [Math]::Round(($_.extensiondata.summary.FreeSpace  / 1GB),2)
    $UsedGB        = $CapacityGB - $FreeGB
    $ProvisionedGB = [Math]::Round(($_.extensiondata.summary.Uncommitted / 1GB),2) + $UsedGB

    $ProvisionedPercent = [math]::Round($ProvisionedGB / $CapacityGB * 100,1)
    $FreePercent = [math]::Round($FreeGB / $CapacityGB * 100,1)
    $nbVM = ($_ | Get-VM | where powerstate -eq Poweredon).count

    IF (($ProvisionedPercent -gt $DatastoreHighProvPercent) -or ($FreePercent -lt $DatastoreLowPercent) -or ($nbVM -gt $DatastoreTooManyVM)) {

        [pscustomobject]@{
            Datastore     = $_.name
            Capacity      = [string]$CapacityGB + " GB"
            FreeSpaceGB  = [string]$FreeGB + " GB"
            FreeSpace     = [string]$FreePercent + " %"
            Provisioned  = [string]$ProvisionedPercent + " %"
            NbRunningVMs  = $nbVM
        }

    }

} | Sort-Object FreeSpace


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

$CriticalState = $Output | Where-Object {[int]($_.FreeSpace -split " %")[0] -lt 12 -or [int]($_.Provisioned -split " %")[0] -gt 180 -or $_.NbRunningVMs -gt 25}
$WarningState  = $Output | Where-Object {[int]($_.FreeSpace -split " %")[0] -lt $DatastoreLowPercent -or [int]($_.Provisioned -split " %")[0] -gt $DatastoreHighProvPercent -or $_.NbRunningVMs -gt $DatastoreTooManyVM}
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