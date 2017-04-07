##==============================================================================
##==============================================================================
##  SCRIPT.........:  Microsoft.PowerShellISE_profile.ps1
##  AUTHOR.........:  David Nandell
##  EMAIL..........:  
##  VERSION........:  5
##  DATE...........:  2011-04-16
##  COPYRIGHT......:  2011, David Nandell
##  LICENSE........:  
##  REQUIREMENTS...:  Powershell v2.0 or higher
##
##  DESCRIPTION....:  This is my Powershell ISE Profile.
##
##  NOTES..........:  
## 
##  CUSTOMIZE......:  Edit working directory based on target machine
##==============================================================================
##  REVISED BY.....:  
##  EMAIL..........:  dnandell@gmail.com
##  REVISION DATE..:  2016-04-29
##  REVISION NOTES.:  
##
##==============================================================================
##==============================================================================
## #REQUIRES -version 2.0 or higher

##==============================================================================
##  START <CODE>
##==============================================================================

    ##--------------------------------------------------------------------------
    ##  Display Installed Version of PowerShell
    ##--------------------------------------------------------------------------
	$PSVersionTable.PSVersion
   
    ##--------------------------------------------------------------------------
    ##  Begin Transcript
    ##--------------------------------------------------------------------------
    Write-Verbose ("[{0}] Initialize Transcript" -f (Get-Date).ToString()) -Verbose

	If ($host.Name -eq "ConsoleHost") {

 	$transcripts = (Join-Path $Env:USERPROFILE "\Documents\WindowsPowerShell\Transcripts")

    	If (-Not (Test-Path $transcripts)) {

		New-Item -path $transcripts -Type Directory | out-null

	}

	$global:TRANSCRIPT = ("{0}\PSLOG_{1:MM-dd-yyyy}.txt" -f $transcripts,(Get-Date))

	Start-Transcript -Path $transcript -Append

	Get-ChildItem $transcripts | Where {

		$_.LastWriteTime -lt (Get-Date).AddDays(-14)

		} | Remove-Item -Force -ea 0

	}

    ##--------------------------------------------------------------------------
    ##  Set working directory
    ##--------------------------------------------------------------------------
	Set-Location 'C:\Users\n158832\Documents\WindowsPowerShell'

    ##--------------------------------------------------------------------------
    ##  Set Whoami Alias
    ##--------------------------------------------------------------------------
	set-alias whoami Ask-Who

    ##--------------------------------------------------------------------------
    ## Set Notepad Alias
    ##--------------------------------------------------------------------------	
	##Open Notepad function by typing: pro
	function pro { notepad $profile }

    ##--------------------------------------------------------------------------
    ## Set Execution Policy Level
    ##--------------------------------------------------------------------------
	Set-ExecutionPolicy RemoteSigned Process

    ##--------------------------------------------------------------------------
    ## Set Maximum History Count
    ##--------------------------------------------------------------------------
	$maximumhistorycount=5000	
	cd C:\

    ##--------------------------------------------------------------------------
    ## Import DataOntap Modules
    ##--------------------------------------------------------------------------
	Import-module dataontap

##==============================================================================
##  SUBROUTINES/FUNCTIONS/CLASSES
##==============================================================================
    ##--------------------------------------------------------------------------
    ##  FUNCTION.......:  Prompt
    ##  PURPOSE........:  Alters the POSH prompt to output the current 
    ##                    directory, as well as the HistoryID for each command. 
    ##                    Also alters the Window title to display the computer 
    ##                    name and current working directory.
    ##  ARGUMENTS......:  
    ##  EXAMPLE........:  
    ##  REQUIREMENTS...:  
    ##  NOTES..........:  
    ##--------------------------------------------------------------------------
    function Prompt
    {
        $compName = $env:COMPUTERNAME
        $id = 1
        $historyItem = Get-History -Count 1
        if($historyItem)
        {
            $id = $historyItem.Id +1
        }
        Write-Host -ForegroundColor DarkGray "`n[$(Get-Location)]"
        Write-Host -NoNewLine "HistoryID:$id "
        $host.UI.RawUI.WindowTitle = "$compName - $(Get-Location)"
    }

    ##--------------------------------------------------------------------------
    ##  FUNCTION.......:  Ask-Who
    ##  PURPOSE........:  Returns the current username and domain.
    ##  ARGUMENTS......:  
    ##  EXAMPLE........:  Ask-Who
    ##  REQUIREMENTS...:  
    ##  NOTES..........:  
    ##--------------------------------------------------------------------------
    function Ask-Who
    {
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name		
    }

##==============================================================================
##  Microsoft Script Browser Add-ons
##==============================================================================



##==============================================================================
##  END </CODE>
##==============================================================================