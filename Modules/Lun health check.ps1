Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = $VMHost | ForEach-Object {

    $AllLun = $_ | Get-scsilun 
    
    $AllLun | Get-scsilunpath | Where-Object {$_.state -eq "dead" -or $_.state -eq "Unknown" -or $_.state -eq "Disabled"} | ForEach-Object {

        $lunid = $_.SCSILun

        [pscustomobject]@{

            Datastore =  $datastore | Where-Object {$_.ExtensionData.Info.Vmfs.Extent.diskname -contains $lunid} | select -ExpandProperty name
            Lun = $lunid
            'Lun State' = ($AllLun | Where-Object {$_.canonicalname -eq $lunid}).extensiondata.operationalstate
            Path = $_.LunPath
            'Path State' = $_.State

        }

    }

} | Sort-Object 'Path State'


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

$CriticalState = $Output | Where-Object {$_.'Path State' -eq "dead" -or $_.'Lun State' -ne "ok"}
$WarningState  = $Output | Where-Object {$_.'Path State' -eq "Unknown" -or $_.'Path State' -eq "Disabled"}
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