<#
------------------------------------------------

Name        : zInfraReport
Author      : Xavier Avrillier
Last Update : 16/03/2017
Version     : 0.1
Website     : http://vxav.fr

"Set-AlternatingRows" function by Martin Pugh

------------------------------------------------
#>

param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $VCENTER,
    [PSCredential]$Credential,
    $DefaultValue = $(Import-Csv .\DefaultValues.csv -Delimiter ";"),
    $Protocol     = "https",
    $EMAIL        = $(Read-Host "Email report when finished Y/N [n]"),
    $OPENHTML     = $(Read-Host "Open report when finished Y/N [$($DefaultValue.openreport)]"),
    $HTMLFile     = $(Read-Host "Path to report file [$($DefaultValue.htmlfile)]"),
    $TO           = $(IF ($EMAIL -eq "Y") {read-host "Send email to [$($DefaultValue.sendto)]"}),
    $FROM         = $(IF ($EMAIL -eq "Y") {read-host "Send email from [$($DefaultValue.sendfrom)]"}),
    $SMTP         = $(IF ($EMAIL -eq "Y") {read-host "SMTP server [$($DefaultValue.smtp)]"})
)

Start-Transcript -Path ".\$($MyInvocation.MyCommand.Name).log"

######################
# Connection to vCenter
######################

Try {
Import-Module "VMware.VimAutomation.Core","VMware.VimAutomation.Sdk"

$params = @{Server = $VCENTER ; Protocol = $Protocol}

if ($Credential) {$params.Add('Credential',$Credential)}

Connect-VIServer @params 3>&1 | Out-Null

} CATCH {
    Write-Error $_.Exception -ErrorAction stop
    pause
}

IF ($DefaultVIserver.name -ne $VCENTER) {write-error "Connection to vcenter failed";break}

######################
# Report settings
######################

IF (!$HTMLFile) {$HTMLFile = $DefaultValue.htmlfile}
IF (!$OPENHTML) {$OPENHTML = $DefaultValue.openreport}

IF ($EMAIL -eq "Y") {
    IF (!$TO)   {$TO   = $DefaultValue.sendto}
    IF (!$FROM) {$FROM = $DefaultValue.sendfrom}
    IF (!$SMTP) {$SMTP = $DefaultValue.smtp}
   $subject = "$($DefaultVIserver.name) infra report" 
}

IF (Test-Path ".\img\$($DefaultVIserver.name).jpg") {
    $HeadPicture = ".\img\$($DefaultVIserver.name).jpg"
} ELSE {
    $HeadPicture = ".\img\default-vcenter.jpg"
}

######################
# HTML preparation
######################

# HTML colors: http://www.w3schools.com/colors/colors_names.asp

$Header = @"
<style>
    TABLE {width: 90%; margin: 0px; padding: 0px;}
    TH {text-align: left;font-family: Tahoma, sans-serif;color: #018AC0;font-size: 8pt}
    TD {padding: 0px;font-size: 8pt;font-family: Tahoma, sans-serif;}
    .odd  { background-color:#ffffff; }
    .even { background-color:#E9E9E9; }
</style>

<title>$($DefaultVIserver.name) report</title>

<div align="center" style="background-color:447188;">
    <a href="https://$($DefaultVIserver.name)"><img src=$HeadPicture></a>
</div>

<div align="center"> 

<table><tr bgcolor="#A9A9A9">
    <td style="color:#FFFFFF;">
        Report date: <b>$(Get-Date -Format F)</b>
        <br>
        Server connected : <b>$($DefaultVIserver.name)</b>
        <br>
        <b>$((Get-ChildItem ./Modules *.ps1).count)</b> modules processed
    </td>
</tr></table>

"@
$Footer = @"

</div>

<br>

<div align="center" style="background-color:447188;">
	<font color="FFFFFF">
	    zInfraReport
	</font>
</div>

"@

######################
# Utility functions
######################

Function Set-AlternatingRows {
	<#
	.NOTES
		Author:         Martin Pugh
		Twitter:        @thesurlyadm1n
		Spiceworks:     Martin9700
		Blog:           www.thesurlyadmin.com
		
		Changelog:
			1.1         Modified replace to include the <td> tag, as it was changing the class
                        for the TH row as well.
            1.0         Initial function release
	.LINK
		http://community.spiceworks.com/scripts/show/1745-set-alternatingrows-function-modify-your-html-table-to-have-alternating-row-colors
    .LINK
        http://thesurlyadmin.com/2013/01/21/how-to-create-html-reports/
	#>
    [CmdletBinding()]
   	Param(
       	[Parameter(Mandatory,ValueFromPipeline)]
        [string]$Line,
       
   	    [Parameter(Mandatory)]
       	[string]$CSSEvenClass,
       
        [Parameter(Mandatory)]
   	    [string]$CSSOddClass
   	)
	Begin {
		$ClassName = $CSSEvenClass
	}
	Process {
		If ($Line.Contains("<tr><td>"))
		{	$Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
			If ($ClassName -eq $CSSEvenClass)
			{	$ClassName = $CSSOddClass
			}
			Else
			{	$ClassName = $CSSEvenClass
			}
		}
		Return $Line
	}
}

Function Format-HTML {

param(
    $ObjectArray,
    [string]$TableTitle,
    [string]$Importance,
    [int]$NumberLinesDisplay
)

IF ($ObjectArray) {

    $PreTitle = ""

    Switch ($Importance) {

        "Information" {
            $bgcolor = "RoyalBlue"
            IF ($ObjectArray.count -gt $NumberLinesDisplay) {$PreTitle = '[First ' + $NumberLinesDisplay + ' results out of ' + ($ObjectArray.count) + ']' }
            $Script:HtmlReportInformation += '<br><table><tr bgcolor="' + $bgcolor + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b>  ' + $PreTitle + '</td></tr></table>'
            $Script:HtmlReportInformation += $ObjectArray | select -First $NumberLinesDisplay | ConvertTo-Html | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
        }
        "Warning"     {
            $bgcolor = "Orange"
            IF ($ObjectArray.count -gt $NumberLinesDisplay) {$PreTitle = '[First ' + $NumberLinesDisplay + ' results out of ' + ($ObjectArray.count) + ']' }
            $Script:HtmlReportWarning += '<br><table><tr bgcolor="' + $bgcolor + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b>  ' + $PreTitle + '</td></tr></table>'
            $Script:HtmlReportWarning += $ObjectArray | select -First $NumberLinesDisplay | ConvertTo-Html | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
        }
        "Critical"    {
            $bgcolor = "IndianRed"
            $Script:HtmlReportCritical += '<br><table><tr bgcolor="' + $bgcolor + '"><td style="color:#FFFFFF;"><b>' + $TableTitle + '</b></td></tr></table>'
            $Script:HtmlReportCritical += $ObjectArray | ConvertTo-Html | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
        }

    }
    
} ELSE {

    $bgcolor = "khaki"
    $Script:HtmlReportNull += '<br><table><tr bgcolor="' + $bgcolor + '"><td style="color:#2F4F4F;"><i>' + $TableTitle + ' : 0</i></td></tr></table>'

}

}

######################
# Data gathering and Building HTML sub-reports
######################

$VM        = Get-VM
$VMHost    = Get-VMHost
$Datastore = Get-Datastore

$Modules = Get-ChildItem ./Modules *.ps1
$Processed = 1

$Modules | ForEach-Object {
    
    Write-Progress -PercentComplete ($Processed/$Modules.count*100) -Activity ("$Processed/$($Modules.count) : "+$_.Name -replace '.ps1','')

    $i = &$_.FullName

    $params = @{
        objectarray        = $i | select -Property * -ExcludeProperty TableTitle,Importance,NumberLinesDisplay;
        TableTitle         = $_.name -replace ".ps1",""
        Importance         = $i | select -ExpandProperty importance -Unique;
        NumberLinesDisplay = $i | select -ExpandProperty NumberLinesDisplay #-Unique -ErrorAction SilentlyContinue
    }

    Format-HTML @params
    
    $Processed++
}

Disconnect-VIServer -Confirm:$false

######################
# Building HTML global report
######################

$Header                | Out-File $HTMLFile
$HtmlReportCritical    | Out-File $HTMLFile -Append
$HtmlReportWarning     | Out-File $HTMLFile -Append
$HtmlReportInformation | Out-File $HTMLFile -Append
$HtmlReportNull        | Out-File $HTMLFile -Append
$Footer                | Out-File $HTMLFile -Append


######################
# Issuing report
######################

IF ($EMAIL -eq "Y") {
    
    $Body = [string](Get-Content $HTMLFile).Replace('img\','')

    $params = @{
        To=$TO;
        From=$From;
        SMTP=$SMTP;
        subject=$subject;
        Body=$Body;
        BodyAsHtml=$True;
        Attachments=$HeadPicture
    }

    Send-MailMessage @params
}

IF ($OPENHTML -eq "Y") {&$HTMLFile}

Stop-Transcript