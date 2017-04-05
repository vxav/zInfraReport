Write-Verbose "Running: $($MyInvocation.MyCommand.Name)"

######################
# Query run.
######################
# Declare variables and thresholds here if required.


# Place the output object into the output variable.
# Remember to sort the object in the variable in relevant order (example: sort by snapshot size descending).

$Summary = $VMHost | ForEach-Object {

    [pscustomobject]@{
        Host                      = $_.name
        'NTP server'              = $_.ExtensionData.Config.DateTimeInfo.NtpConfig.Server | ForEach-Object {"$_ "}
        'DNS server'              = [string]($_.ExtensionData.Config.Network.DnsConfig.Address | ForEach-Object {"$_ "})
        'Syslog server'           = ($_ | Get-VMHostSyslogServer).Host
        'DomainName/SearchDomain' = "$($_.ExtensionData.Config.Network.DnsConfig.DomainName)/$($_.ExtensionData.Config.Network.DnsConfig.SearchDomain)"
        'vSwitch/Portgroups'      = "$($_.ExtensionData.Config.Network.vswitch.count)/$($_.ExtensionData.Config.Network.Portgroup.count)"
        'Service On/Off'          = "$(($_.ExtensionData.Config.Service.Service | where policy -eq on).count)/$(($_.ExtensionData.Config.Service.Service | where policy -eq off).count)"
        'FW rules On/Off'         = "$(($_.ExtensionData.Config.Firewall.Ruleset | where Enabled -eq $true).count)/$(($_.ExtensionData.Config.Firewall.Ruleset | where Enabled -eq $false).count)"
        Ipmi                      = IF ($_.ExtensionData.Config.Ipmi) {"Configured"} ELSE {"Not Configured"}
        VmotionEnabled            = $_.ExtensionData.Summary.Config.VmotionEnabled
        PowerPolicy               = $_.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy
    }

}

IF (

$Summary | select * -ExcludeProperty Host | 
    Get-Member -MemberType NoteProperty | 
    select -ExpandProperty name | 
    ForEach-Object {
        $prop=$_
        $Summary | group-object -Property $prop
    } | where count -lt $VMHost.count

) {

$Output = $Summary | sort-object host

}

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