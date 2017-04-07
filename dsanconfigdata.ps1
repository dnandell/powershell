Param( 
  $csvFile = "C:\SCRIPTING\Script_Projects\PS1_files\Editing\DSANConfigs\2013-07-29_DSAN_Ports.csv", 
  $path = "C:\SCRIPTING\dsanconfigdata.xlsx" 
) 
$processes = Import-Csv -Path $csvFile 
$Excel = New-Object -ComObject excel.application 
$Excel.visible = $false 
$workbook = $Excel.workbooks.add() 
$excel.cells.item(5,1) = "NAME" 
$excel.cells.item(5,2) = "INDEX" 
$excel.cells.item(5,3) = "ADDRESS" 
$excel.cells.item(5,4) = "SPEED" 
$excel.cells.item(5,5) = "STATE"
$excel.cells.item(5,6) = "TYPE"
$excel.cells.item(5,7) = "LABEL"
$excel.cells.item(5,8) = "WWN"
$excel.cells.item(5,9) = "ALIAS"
$excel.cells.item(5,10) = "NICKNAME"
$excel.cells.item(5,11) = "NODE_ID_STRING" 
$i = 2 
foreach($process in $processes) 
{ 
 $excel.cells.item($i,1) = $process.name 
 $excel.cells.item($i,2) = $process.index 
 $excel.cells.item($i,3) = $process.address 
 $excel.cells.item($i,4) = $process.speed 
 $excel.cells.item($i,5) = $process.state
 $excel.cells.item($i,6) = $process.type
 $excel.cells.item($i,7) = $process.label
 $excel.cells.item($i,8) = $process.wwn
 $excel.cells.item($i,9) = $process.alias
 $excel.cells.item($i,10) = $process.nickname
 $excel.cells.item($i,11) = $process.nodeidstring 
 $i++ 
} #end foreach process 
$workbook.saveas($path) 
$Excel.Quit() 
Remove-Variable -Name excel 
[gc]::collect() 
[gc]::WaitForPendingFinalizers()