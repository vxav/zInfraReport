<#
------------------------------------------------

Name        : zInfraReport
Author      : Xavier Avrillier
Last Update : 13/04/2017
Version     : 0.9
Website     : http://vxav.fr

The word "Module" in this script refers to each folder inside the Modules folder (except excluded).

------------------------------------------------
#>

param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $VCENTER,

    [string]$SetDefaultValues = $(
        $def=Read-Host "Set the default values Y/N [n]"
        IF ($def -eq "Y") {&.\Metadata\Set-DefaultValues.ps1}
    ),

    [PSCredential]
    $Credential,

    [PSCustomObject]
    $DefaultValue = $(Import-Csv .\Metadata\DefaultValues.csv),
    
    [ValidateSet("http","https")]
    [string]$Protocol = "https",
    [string]$EMAIL    = $(Read-Host "Email report when finished Y/N [n]"),
    [string]$OPENHTML = $(Read-Host "Open report when finished Y/N [$($DefaultValue.displayreport)]"),
    [string]$HTMLFile = $(Read-Host "Path to HTML report file [.\zInfraReport_$VCENTER]"),
    [string]$TO       = $(IF ($EMAIL -eq "Y") {read-host "Send email to [$($DefaultValue.sendto)]"}),
    [string]$FROM     = $(IF ($EMAIL -eq "Y") {read-host "Send email from [$($DefaultValue.sendfrom)]"}),
    [string]$SMTP     = $(IF ($EMAIL -eq "Y") {read-host "SMTP server [$($DefaultValue.smtp)]"})
)

######################
# Import utility functions and set variables
######################

. ".\Metadata\Utility-Functions.ps1"

$PowerCLIModules   = "VMware.VimAutomation.Core","VMware.VimAutomation.Sdk","VMware.VumAutomation"
$JQueryFile        = "Metadata/js/jquery-3.2.1.min.js" # Must use / instead of \ for html notation
$JQuerySorterFile  = "Metadata/js/jquery.tablesorter.min.js" # Must use / instead of \ for html notation
$CSSFile           = "Metadata/css/zInfraReport.css" # Must use / instead of \ for html notation
$TemplateIndexFile = ".\Metadata\Template-index.html"
$FileEncoding      = "utf8"
$date              = Get-Date

Clear-Host

Start-Transcript -Path ".\$($MyInvocation.MyCommand.Name).log"

######################
# Connection to vCenter
######################

write-output "***   --------------------------------"
write-output "***   Connecting to vcenter : $VCENTER"

IF (!(Connect-vCenter -VCENTER $VCENTER -Protocol $Protocol -Credential $Credential)) {Throw "VCenter connection issue";Exit}

######################
# Preparing report utilities
######################

write-output "***   --------------------------------"
write-output "***   Preparing report utilities"

IF (!$HTMLFile) {$HTMLFile = "zInfraReport-$($DefaultVIserver.name).html"}
    ELSEIF ($HTMLFile -notlike "*.html") {$HTMLFile = "$HTMLFile.html"}

IF (!$OPENHTML) {$OPENHTML = $DefaultValue.displayreport}

IF ($EMAIL -eq "Y") {
    IF (!$TO)   {$TO   = $DefaultValue.sendto}
    IF (!$FROM) {$FROM = $DefaultValue.sendfrom}
    IF (!$SMTP) {$SMTP = $DefaultValue.smtp}
   $subject = "$($DefaultVIserver.name) infra report - $(get-date -Format s)" 
}

IF (Test-Path ".\img\$($DefaultVIserver.name).jpg") {$HeadPicture = "..\img\$($DefaultVIserver.name).jpg"} # Added a dot to make it accessible from the "Report" sub-folder
    ELSE {$HeadPicture = "..\img\default-vcenter.jpg"}

######################
# Preparing objects for every modules
# These object will contain all the info for each module (folders in ".\Modules")
######################

write-output "***   --------------------------------"
write-output "***   Preparing report modules objects"

Try {

$IndexFile = Copy-Item $TemplateIndexFile $HTMLFile -Force -PassThru 

IF (!(Test-Path "$($IndexFile.Directory)\Reports\")) {New-Item -ItemType Directory "$($IndexFile.Directory)\Reports\"}

$ModuleGroups = Create-ModuleObjects -ModuleGroups (Get-ChildItem Modules | Where-Object {$_.PSIsContainer -and $_.name -ne "excluded"}) -IndexFile $IndexFile

} CATCH {
    Write-Error $_.Exception -ErrorAction stop
    Break
}

######################
# HTML preparation
######################

# HTML colors (managed in zInfraReport.css) : http://www.w3schools.com/colors/colors_names.asp
# The end of the header is generated on a per module basis to allow for the creation of the button bar

write-output "***   --------------------------------"
write-output "***   Preparing HTML header and footer"

$Header = @"
<HTML lang="en-US">

<HEAD>

<link rel="stylesheet" type="text/css" href="../$CSSFile">
<script type="text/javascript" src="../$JQueryFile"></script>
<script type="text/javascript" src="../$JQuerySorterFile"></script>
<title>$($DefaultVIserver.name) report</title>

</HEAD>

<BODY>

<div align="center" class="headerfooterbg">
    <a href="$("../$($IndexFile.BaseName).html")"><img src=$HeadPicture></a>
</div>

<div align="center">

"@

$Footer = @'

</div>

<br>

<div align="center" class="headerfooterbg">
	    zInfraReport
</div>

<script type="text/javascript">

$(function(){
PLACEJSScriptIDsHERE
});

function Listederoulante() {
    i = document.TheForm.List.selectedIndex;
    if (i == 0) return;
    url = document.TheForm.List.options[i].value;
    parent.location.href = url;
}

</script>

</BODY>
</HTML>

'@

$ListeHtml =
@"

<FORM name="TheForm" method="post">
<SELECT name="List" onChange="Listederoulante(this.form)">
<OPTION VALUE="">- Change report -
REPLACELISTE
</SELECT>
</FORM>
"@

######################
# Gathering data
######################

write-output "***   --------------------------------"
write-output "***   Gathering environment data"

Gather-EnvironmentData

######################
# Building HTML sub-reports
######################

write-output "***   --------------------------------"

$ModuleGroups | ForEach-Object {
    
    write-output "***   Processing $($_.ModuleGroupFolder.name)"

    $Script:CriticalCount = 0
    $Script:WarningCount  = 0
    $Script:InfoCount     = 0

    $Modules = Get-ChildItem $_.ModuleGroupFolder.fullname "*.ps1"
    
    $Processed = 1

    $host.privatedata.ProgressBackgroundColor = "DarkBlue"

    # Running ps1 scripts of this module

    $Modules | ForEach-Object {
        
        write-output "***     - Sub-processing $($_.name)"

        Write-Progress -Activity ($Modules.DirectoryName.split('\') | select -Last 1) -PercentComplete ($Processed/$Modules.count*100) -Status ("$Processed/$($Modules.count) : "+$_.Name -replace '.ps1','')

        $i = &$_.FullName

        $params = @{
            objectarray        = $i | select -Property * -ExcludeProperty TableTitle,Importance,NumberLinesDisplay;
            TableTitle         = $_.name -replace ".ps1",""
            Importance         = $i | select -ExpandProperty importance -Unique;
            NumberLinesDisplay = $i | select -ExpandProperty NumberLinesDisplay -Unique #-ErrorAction SilentlyContinue
        }

        Format-HTML @params
    
        $Processed++
    }

    # Setting the button color and index row of this module

    write-output "***     - Setting button color and preparing end of header"

    IF ($HtmlReportCritical) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME","critical"
        $CriticalIndex += 
@"
<tr>
<td class="criticalindex">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSEIF ($HtmlReportWarning) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME","warning"
        $WarningIndex += 
@"
<tr>
<td class="warningindex">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSEIF ($HtmlReportInformation) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME","information"
        $InfoIndex += 
@"
<tr>
<td class="infoindex">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSE {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME","noresult"
        $NullIndex += 
@"
<tr>
<td class="noresultindex">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    }


    # Preparing this module's end of header without the button bar

    $PostHeader = @"

BUTTONSBAR

<table><tr class="reportinfo">
    <td class="reportinfo">
        Report date: <b>$date</b>
        <br>
        Server connected : <b>$($DefaultVIserver.name)</b>
        <br>
        Category : <b>$($_.ModuleGroupFolder.name)</b>
    </td>
</tr></table>

"@

    # Store report without the button bar nor button colors in this module's variable

    write-output "***     - Writing report in the property of the module's object"

    $_.ModuleGroupReportContent =  $Header
    $_.ModuleGroupReportContent += $PostHeader
    $_.ModuleGroupReportContent += $HtmlReportCritical
    $_.ModuleGroupReportContent += $HtmlReportWarning
    $_.ModuleGroupReportContent += $HtmlReportInformation
    $_.ModuleGroupReportContent += "<br>"
    $_.ModuleGroupReportContent += $HtmlReportNull
    $_.ModuleGroupReportContent += $Footer -replace "PLACEJSScriptIDsHERE",$JSScriptIDs

    Clear-Variable HtmlReportCritical,HtmlReportWarning,HtmlReportInformation,HtmlReportNull,PostHeader,JSScriptIDs -ErrorAction SilentlyContinue

    write-output "***   Processing finished for $($_.ModuleGroupFolder.name)"
    write-output "***   ----------------"
}

######################
# Building report and place button bar
######################

write-output "***   --------------------------------"
write-output "***   Writting reports content in report files"

$ModuleGroups | ForEach-Object {
    
    $CurModuleGroup = $_

    # Creating button bar with associated colors for the current module 

    $ModuleGroups | ForEach-Object {

        IF ($_.ModuleGroupFolder -ne $CurModuleGroup.ModuleGroupFolder) {
        
            $Bouton += $_.ModuleGroupButton
        
        } 
    
    }

    $REPLACELIST = $ListeHtml -replace "REPLACELISTE",$Bouton

    # Placing button bar in the report of the current module

    IF (($ModuleGroups | measure-object).count -eq 1) {$rapport = $_.ModuleGroupReportContent -replace "BUTTONSBAR","<!-- Button list disabled when only a single report -->"}
        ELSE {$rapport = $_.ModuleGroupReportContent -replace "BUTTONSBAR",$REPLACELIST}

    # Placing the report content in its HTML file

    $rapport | Out-File $_.ModuleGroupReport -Encoding $FileEncoding

    IF ($Bouton) {Clear-Variable Bouton}

}

write-output "***   --------------------------------"
write-output "***   Writting index file"

(Get-Content $IndexFile) `
    -replace "THISVCENTER",$Global:DefaultVIServer.name`
    -replace "VCENTERVERSION",$Global:DefaultVIServer.ExtensionData.Content.About.FullName `
    -replace "PLACEREPORTSHERE","$CriticalIndex $WarningIndex $InfoIndex $NullIndex" `
    -replace "DATEHERE",$date `
    | Out-File $IndexFile -Force -Encoding $FileEncoding

Disconnect-VIServer -Confirm:$false

######################
# Issuing report
######################

    IF ($EMAIL -eq "Y") {
        $params = @{
            To=$TO;
            From=$From;
            SMTP=$SMTP;
            subject=$subject;
            Body="Find reports for $($DefaultVIserver.name) attached";
            Attachments=$ModuleGroups.ModuleGroupReport
        }
        Send-MailMessage @params
    }

IF ($OPENHTML -eq "Y") {&$IndexFile}

write-output "***   Ground control: Out"

Stop-Transcript



