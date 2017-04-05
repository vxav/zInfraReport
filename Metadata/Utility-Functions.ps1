Function Gather-EnvironmentData {

######################
# Data gathering 
# TO DO: 
#   > Move any data gathering from the module scripts here (RDY, LUN ...)
#   > Leverage Get-view better in the script and ideally use only that
######################

    $host.privatedata.ProgressBackgroundColor = "DarkRed"

    Write-Progress -PercentComplete 0 -Activity "Gathering environment data"

    write-output "***     - Gathering VM"
    $Global:VM        = Get-VM

    write-output "***     - Gathering Hosts"
    $Global:VMHost    = Get-VMHost
    $Global:VMHostView= $VMHost | Get-View

    write-output "***     - Gathering Datastores"
    $Global:Datastore = Get-Datastore

    write-output "***     - Gathering Clusters"
    $Global:Cluster   = Get-Cluster

    write-output "***     - Gathering VM latencies"
    $Global:Latencies24H = $VM | Where powerstate -eq poweredon |  get-stat -stat disk.maxtotallatency.latest -IntervalMins 5

}

Function Connect-vCenter {

Param(
    $VCENTER,
    $Protocol,
    $Credential
)

Try {
    Import-Module $PowerCLIModules

    $params = @{Server = $VCENTER ; Protocol = $Protocol}
    if ($Credential) {$params.Add('Credential',$Credential)}

    Connect-VIServer @params 3>&1 | Out-Null
} CATCH {
    Write-Error $_.Exception -ErrorAction stop
    Exit
}

$true

}

Function Format-HTML {

# Store the HTML results in 4 modules to order them at the end of the processiong of the current module

param(
    $ObjectArray,
    [string]$TableTitle,
    [string]$Importance,
    [int]$NumberLinesDisplay
)

    write-output "***     - HTML formatting of $TableTitle"

    IF ($ObjectArray) {
   
        $PreTitle = ""  # Used next to the title when the number of lines is limited

        Switch ($Importance) {

            "Information" {
                IF ($ObjectArray.count -gt $NumberLinesDisplay) {$PreTitle = '[First ' + $NumberLinesDisplay + ' results out of ' + ($ObjectArray.count) + ']' }
                $Script:HtmlReportInformation += ' 
                <br><table><tr bgcolor="' + $ColorInfo + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b>  ' + $PreTitle + '</td></tr></table>' # Jump a line to make the html file more readable
                $Script:HtmlReportInformation += $ObjectArray | select -First $NumberLinesDisplay | ConvertTo-Html
                $Script:InfoCount++
            }
            "Warning"     {
                IF ($ObjectArray.count -gt $NumberLinesDisplay) {$PreTitle = '[First ' + $NumberLinesDisplay + ' results out of ' + ($ObjectArray.count) + ']' }
                $Script:HtmlReportWarning += '
                <br><table><tr bgcolor="' + $ColorWarning + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b>  ' + $PreTitle + '</td></tr></table>'# Jump a line to make the html file more readable
                $Script:HtmlReportWarning += $ObjectArray | select -First $NumberLinesDisplay | ConvertTo-Html
                $Script:WarningCount++
            }
            "Critical"    {
                $Script:HtmlReportCritical += '
                <br><table><tr bgcolor="' + $ColorCritical + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b></td></tr></table>'# Jump a line to make the html file more readable
                $Script:HtmlReportCritical += $ObjectArray | ConvertTo-Html
                $Script:CriticalCount++
            }

        }
    
    } ELSE {

        $Script:HtmlReportNull += '
        <table><tr bgcolor="' + $ColorNull + '"><td style="color:#2F4F4F;"><i>' + $TableTitle + ' : 0</i></td></tr></table>'# Jump a line to make the html file more readable

    }

}

Function Create-ModuleObjects {

Param(
    $ModuleGroups,
    $indexFile
)

    $ModuleGroups | ForEach-Object {

        $ReportRelativeURL = "./$($IndexFile.BaseName)-$($_.name).html"

        IF (!(Test-Path  "$($_.FullName)\.description.txt")) {New-item "$($_.FullName)\.description.txt"}

        [pscustomobject]@{
             # Folder object of this module
            ModuleGroupFolder = $_  
             # HTML report file object for this module
            ModuleGroupReport = New-Item "$($IndexFile.Directory)\Reports\$($IndexFile.BaseName)-$($_.name).html" -Force -Type File  
             # HTML report content. Stored in this property to way for all reports to run in order to get the button color of all reports
            ModuleGroupReportContent = ""  
             # Description of the report in the index
            ModuleGroupDescription = $_ | Get-ChildItem | where name -eq ".Description.txt" | Get-content 
             # Used for the link to the report in the index
            ModuleGroupUrl = "./Reports/$($IndexFile.BaseName)-$($_.name).html"
             # HTML string to give the button linking to this report a color according to its criticity (red, orange, blue, yellow)
            ModuleGroupButtonColor = ""  
             # HTML for the button to this report without color (REPLACEME).
            ModuleGroupButton = 
@"
<OPTION style="background-color:REPLACEME" VALUE="$ReportRelativeURL">$($_.basename)

"@  


        }
    }

}