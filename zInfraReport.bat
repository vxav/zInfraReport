REM Change directory to the location of the script being called.
REM %~dp0 : directory of the current file
CD %~dp0

REM Call powershell with a file with the same name but ps1 as extension
REM Output everything to a file with the same name but log as extension
REM %~n0 : name of the current file without extension

REM Report vcenter

C:\Windows\System32\cmd.exe /c powershell.exe -noninteractive -noprofile -File %~dp0\zinfrareport.ps1 -VCENTER "My-vcenter" -SetDefaultValues "N" -HTMLFILE "Path\to\my\web\server\folder" -EMAIL "N" -OPENHTML "N" -TO "Johny@test.local" -FROM "my-vcenter@test.local" -SMTP "smtp@test.local"

