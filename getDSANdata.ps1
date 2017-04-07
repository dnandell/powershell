##==============================================================================
##==============================================================================
##  SCRIPT.........:  getDSANdata.ps1
##  AUTHOR.........:  David Nandell
##  EMAIL..........:  nandell.david@principal.com
##  VERSION........:  1
##  DATE...........:  Updated 07/29/2013
##  COPYRIGHT......:  2013, David Nandell
##  LICENSE........:  
##  REQUIREMENTS...:  Powershell v2.0 or higher
##
##  DESCRIPTION....:  PowerShell script to inventory storage admin console.
##
##  NOTES..........:  Created 07/29/2013
## 
##  CUSTOMIZE......:  
##==============================================================================
##  REVISED BY.....:  
##  EMAIL..........:  
##  REVISION DATE..:  
##  REVISION NOTES.:
##
##==============================================================================
##==============================================================================
## #REQUIRES -version 2.0 or higher

##==============================================================================
##  START <CODE>
##==============================================================================

$Date = (Get-Date -format "yyyy-MM-dd")

$dir = "C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\*_DSAN_Ports.txt"
$latest = Get-ChildItem -Path $dir | Sort-Object LastWriteTime -Descending |  Where-Object { $_.CreationTime -ge $Date } | Select-Object -First 1
$latest.name

Copy-Item $latest.name -Destination "C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\Test" –Recurse
Import-CSv "C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\Test\*_DSAN_Ports.txt" -header NAME, INDEX, ADDRESS, SPEED,STATE, TYPE, LABEL, WWN, ALIAS, NICKNAME, NODE_ID_STRING | Export-csv C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\dsanconfig.csv -notypeinfo

$xl = new-object -comobject excel.application
$xl.visible = $true
$Workbook = $xl.workbooks.open(“C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\dsanconfig.csv”)
$Worksheets = $Workbooks.worksheets
$Workbook.SaveAs(“C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\dsanconfig.xls”,1)
$Workbook.Saved = $True
$xl.Quit()



##==============================================================================
##  END </CODE>
##==============================================================================