##==============================================================================
##==============================================================================
##  SCRIPT.........:  PFG_StgSolutions_ConsoleInventory.ps1 (aka. stgcnsinventory.ps1)
##  AUTHOR.........:  David Nandell
##  EMAIL..........:  nandell.david@principal.com
##  VERSION........:  1
##  DATE...........:  Updated 07/25/2013
##  COPYRIGHT......:  2013, David Nandell
##  LICENSE........:  
##  REQUIREMENTS...:  Powershell v2.0 or higher
##
##  DESCRIPTION....:  PowerShell script to inventory storage admin console.
##
##  NOTES..........:  Created 07/25/2013
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

#Get list of servers
Get-Content "C:\Scripting\servers.txt"

#ReportDate
Get-Date | Select -Property DateTime | Out-File C:\Scripting\inventory.txt

#General Information
gwmi Win32_ComputerSystem  | 
Select -Property Model , Manufacturer , Description , PrimaryOwnerName , SystemType | Format-List * | Out-File C:\Scripting\inventory.txt -Append

#CPU Information
gwmi Win32_Processor  | 
Select SystemName , Name , Manufacturer , status | Format-List * | Out-File C:\Scripting\inventory.txt -Append

#Logical Disk Information
gwmi Win32_LogicalDisk -Filter DriveType=3 | 
Select DeviceID , @{Name=”size(GB)”;Expression={“{0:N1}” -f($_.size/1gb)}}, @{Name=”freespace(GB)”;Expression={“{0:N1}” -f($_.freespace/1gb)}} | Format-List * | Out-File C:\Scripting\inventory.txt -Append

#Operating System Information
gwmi Win32_OperatingSystem | Select -Property Caption , CSDVersion , OSArchitecture | Format-List * | Out-File C:\Scripting\inventory.txt -Append

#BIOS Information
gwmi Win32_BIOS | Select -Property PSComputerName , Manufacturer , Version | Format-List * | Out-File C:\Scripting\inventory.txt -Append


##==============================================================================
##  END </CODE>
##==============================================================================
