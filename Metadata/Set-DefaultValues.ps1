$r = Import-CSV .\Metadata\DefaultValues.csv

$r | gm -Type NoteProperty | select -ExpandProperty Name | ForEach-Object {
    $r.$_ = Read-Host "Enter default value for $_"
}

$r | export-csv .\Metadata\DefaultValues.csv -NoTypeInformation
