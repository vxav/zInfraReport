Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.

$ViewTypes = "ComputeResource","ClusterComputeResource","Datacenter","Datastore","Network","DistributedVirtualPortgroup","DistributedVirtualSwitch","Folder","HostSystem","ResourcePool","VirtualApp","VirtualMachine","VmwareDistributedVirtualSwitch"

function Get-triggeredAlarm {

param(
    [ValidateSet("ComputeResource","ClusterComputeResource","Datacenter","Datastore","Network","DistributedVirtualPortgroup","DistributedVirtualSwitch","Folder","HostSystem","ResourcePool","VirtualApp","VirtualMachine","VmwareDistributedVirtualSwitch")]
    $ViewType
)

$ViewType | ForEach-Object {

$view = Get-View -viewtype $_

foreach($triggered in $view.TriggeredAlarmState){
  
  $alarmDef = Get-View -Id $triggered.Alarm
  
  $alarmDef | ForEach-Object {
  [pscustomobject]@{

    Entity = (get-view -id $triggered.entity).name
    Time = get-date $triggered.Time -format u
    Name = $_.info.name
    Status = $triggered.OverallStatus

  }
 
}

}

} | select -Unique *

}

# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Output = Get-triggeredAlarm -ViewType $ViewTypes | Sort-Object Time -Descending


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

$CriticalState = $Output | where Status -eq Red
$WarningState  = $Output | where Status -eq Yellow
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