##==============================================================================
##==============================================================================
##  SCRIPT.........:  pfg_netapp_info.ps1
##  AUTHOR.........:  David Nandell
##  EMAIL..........:  nandell.david@principal.com
##  VERSION........:  1
##  DATE...........:  Updated 12/04/2013
##  COPYRIGHT......:  2013, David Nandell
##  LICENSE........:  
##  REQUIREMENTS...:  Powershell v2.0 or higher
##
##  DESCRIPTION....:  PowerShell script to report on NetApp consoles.
##
##  NOTES..........:  Created 12/04/2013
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
## #REQUIRES -version 2.0 or higher. Written with -version 4.0

##==============================================================================
##  START <CODE>
##==============================================================================

param( [string[]] $Filers)
If ($Filers -eq $NULL) { Write-Host "No filer chosen, script now exiting." ; exit }
Import-Module DataONTAP
$MyCreds = (Get-Credential)
$FileTime = Get-Date -Format "MM-dd-yyyy"
$FileDirectory = 'C:\Users\n158832\Desktop\'

Foreach ($Filer in $Filers){

Connect-NcController $Filer -Credential $MyCreds

#AggregateInfo
$Filename1 = $FileDirectory+"pfg_netapp_aggregates_"+$FileTime+".txt"
Get-NcAggr | Out-File $Filename1 -Encoding ascii
 

#VolumeInfo
$Filename2 = $FileDirectory+"pfg_netapp_volumes_"+$FileTime+".txt"
Get-NcVol | Out-File $Filename2 -Encoding ascii 

#VserverInfo
$Filename3 = $FileDirectory+"pfg_netapp_vservers_"+$FileTime+".txt"
Get-NcVserver | Out-File $Filename3 -Encoding ascii

#VolSpaceInfo
$Filename4 = $FileDirectory+"pfg_netapp_volumespace_"+$FileTime+".txt"
Get-NcVolSpace | Out-File $Filename4 -Encoding ascii

#SystemVersionInfo
$Filename5 = $FileDirectory+"pfg_netapp_systemversioninfo_"+$FileTime+".txt"
Get-NcSystemVersion | Out-File $Filename5 -Encoding ascii

#SnapMirrorInfo
$Filename6 = $FileDirectory+"pfg_netapp_snapmirror_"+$FileTime+".txt"
Get-NcSnapMirror | Out-File $Filename6 -Encoding ascii

#NodeInfo
$Filename7 = $FileDirectory+"pfg_netapp_nodes_"+$FileTime+".txt"
Get-NcNode  |  Out-File $Filename7 -Encoding ascii

#NcNodeInfo
$Filename8 = $FileDirectory+"pfg_netapp_ncnodeinfo_"+$FileTime+".txt"
Get-NcNodeInfo | Out-File $Filename8 -Encoding ascii

#NetInterfaceInfo
$Filename9 = $FileDirectory+"pfg_netapp_netinterface_"+$FileTime+".txt"
Get-NcNetInterface | Out-File $Filename9 -Encoding ascii

}


##==============================================================================
##  END </CODE>
##==============================================================================