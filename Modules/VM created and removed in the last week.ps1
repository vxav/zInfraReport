Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.

$days = 7

# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = Get-VIEvent -Entity ($VM) -Start (Get-Date).AddDays(-$days) -maxsamples ([int]::MaxValue) | ForEach-Object { 

    IF ($_.fullformattedmessage -match "cloned|deployed|created") { 
    
        [pscustomobject]@{
            VM       = $_.vm.name
            Task     = "Created"
            Date     = $_.createdtime
            Username = $_.username
            Event    = $_.fullformattedmessage
         }

    } ELSEIF ($_.fullformattedmessage -like "Removed*on*from*") {

        [pscustomobject]@{
            VM       = $_.vm.name
            Task     = "Removed"
            Date     = $_.createdtime
            Username = $_.username
            Event    = $_.fullformattedmessage
         }

    }    

} | Sort-Object Task

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