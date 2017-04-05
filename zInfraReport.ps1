<#
------------------------------------------------

Name        : zInfraReport
Author      : Xavier Avrillier
Last Update : 05/04/2017
Version     : 0.8
Website     : http://vxav.fr

The word "Module" in this script refers to each folder inside the Modules folder (except excluded).
For each "module", there will be an html file and a button/link to each of them on the report page.

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
$ColorCritical     = "#CD5C5C"
$ColorWarning      = "#FFA500"
$ColorInfo         = "#4169E1"
$ColorNull         = "#FFEBCD"
$ColorBanner       = "0095d3"
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

$IndexFile = Copy-Item ".\Metadata\Template-index.html" $HTMLFile -Force -PassThru

IF (!(Test-Path "$($IndexFile.Directory)\Reports\")) {New-Item -ItemType Directory "$($IndexFile.Directory)\Reports\"}

$ModuleGroups = Create-ModuleObjects -ModuleGroups (Get-ChildItem Modules | Where-Object {$_.PSIsContainer -and $_.name -ne "excluded"}) -IndexFile $IndexFile

} CATCH {
    Write-Error $_.Exception -ErrorAction stop
    Break
}

######################
# HTML preparation
######################

# HTML colors: http://www.w3schools.com/colors/colors_names.asp
# The end of the header is generated on a per module basis to allow for the creation of the button bar

write-output "***   --------------------------------"
write-output "***   Preparing HTML header and footer"

$Header = @"

<SCRIPT>
    function Listederoulante() {
	  i = document.TheForm.List.selectedIndex;
        if (i == 0) return;
        url = document.TheForm.List.options[i].value;
	    parent.location.href = url;
    }
</SCRIPT>

<style>
    TABLE {text-align: left; width: 95%; margin: 0px; padding: 0px;}
    TH {font-size: 8pt;font-family: tahoma, sans-serif;color: #0066cc;}
    TD {padding: 0px;font-size: 8pt;font-family: tahoma, sans-serif;color: #000000;}
    tr:nth-child(even){background-color: #E9E9E9}
</style>

<title>$($DefaultVIserver.name) report</title>

<div align="center" style="background-color:$ColorBanner;">
    <a href="$("../$($IndexFile.BaseName).html")"><img src=$HeadPicture></a>
</div>

<div align="center"> 

"@

$Footer = @"

</div>

<br>

<div align="center" style="background-color:$ColorBanner;">
	<font color="FFFFFF">
	    zInfraReport
	</font>
</div>

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

    # Setting the button color of this module

    write-output "***     - Setting button color and preparing end of header"

    IF ($HtmlReportCritical) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME",$ColorCritical
        $CriticalIndex += 
@"
<tr>
<td style="Border-left:5px solid $ColorCritical;">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSEIF ($HtmlReportWarning) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME",$ColorWarning
        $WarningIndex += 
@"
<tr>
<td style="Border-left:5px solid $ColorWarning;">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSEIF ($HtmlReportInformation) {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME",$ColorInfo
        $InfoIndex += 
@"
<tr>
<td style="Border-left:5px solid $ColorInfo;">
<a href="$($_.ModuleGroupUrl)">$($_.ModuleGroupFolder.name)</a></td>
<td>$($_.ModuleGroupDescription)</td>
<td>$CriticalCount</td>
<td>$WarningCount</td>
<td>$InfoCount</td>
</tr>
"@
    } ELSE {
        $_.ModuleGroupButton = $_.ModuleGroupButton -replace "REPLACEME",$ColorNull
        $NullIndex += 
@"
<tr>
<td style="Border-left:5px solid $ColorNull;">
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

<table><tr bgcolor="#A9A9A9">
    <td style="color:#FFFFFF;">
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
    $_.ModuleGroupReportContent += $Footer

    Clear-Variable HtmlReportCritical,HtmlReportWarning,HtmlReportInformation,HtmlReportNull,PostHeader -ErrorAction SilentlyContinue

    write-output "***   Processing finished for $($_.ModuleGroupFolder.name)"
    write-output "***   ----------------"
}

######################
# Building report and place button bar
######################
# $($ModuleGroups.ModuleGroupButton) replace
$ListeHtml =
@"

<FORM name="TheForm" method="post">
<SELECT name="List" onChange="Listederoulante(this.form)">
<OPTION VALUE="">- Change report -
REPLACELISTE
</SELECT>
</FORM>
"@

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

    IF (($ModuleGroups | measure-object).count -eq 1) {$rapport = $_.ModuleGroupReportContent -replace "BUTTONSBAR","<!-- Button bar disabled when only a single report -->"}
        ELSE {$rapport = $_.ModuleGroupReportContent -replace "BUTTONSBAR",$REPLACELIST}

    # Placing the report content in its HTML file

    $rapport | Out-File $_.ModuleGroupReport

    IF ($Bouton) {Clear-Variable Bouton}

}

write-output "***   --------------------------------"
write-output "***   Writting index file"

(Get-Content $IndexFile) `
    -replace "VCENTERVERSION",$Global:DefaultVIServer.ExtensionData.Content.About.FullName `
    -replace "PLACEREPORTSHERE","$CriticalIndex $WarningIndex $InfoIndex $NullIndex" `
    -replace "DATEHERE",$date `
    | Out-File $IndexFile -Force

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



