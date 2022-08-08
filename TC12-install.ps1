<#
# File: TC12-install.ps1
# Created: Sunday August 7th 2022
# Author: Nick Strickland
# -----
# Last Modified: Monday, 8th August 2022 12:39:14 am
# ----
# Copright 2022 Nick Strickland, nsstrickland@outlook.com>>
# GNU General Public License v3.0 only - http://www.gnu.org/licenses/gpl-3.0-standalone.html
#>

$ApplicationName="TC12"
$DateVer='071222'
$MountDir = "$PSScriptRoot\$ApplicationName-mount\"
$MainLogDir = "$PSScriptRoot\$ApplicationName-install.log"
$MountLogDir = "$PSScriptRoot\$ApplicationName-mount-action.log"
$Preamble=@{Preamble="InstallScript";LogFile=$MainLogDir}
$ProgramList=@( "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")

 # Comment out if checking for most recent java installation

function Out-Log {
    param (
        [Parameter (Mandatory=$True, Position=0)]
        [string]$Preamble,
        [Parameter (Mandatory=$True, Position=1)]
        [string]$Section,
        [Parameter (Mandatory=$True, Position=2)]
        [string]$LogFile,
        [Parameter (Mandatory=$True, Position=3)]
        [string]$Message
    )
    Write-Output -InputObject (("[$Preamble] [$Section] [")+(Get-Date -Format "MM.dd.yy:hh.mm.ss" )+("] $Message"))
}
function Clean-WindowsImage {
    param (
        [Parameter (Mandatory = $true)]
            [int]$ExitCode
    )
    if (Test-Path $MountDir) {
        if ((Get-ChildItem $MountDir).count -gt 0) { 
            try {
                Dismount-WindowsImage -Path $MountDir -Discard -LogPath $MountLogDir
            }
            catch {
                Out-Log @Preamble -Section "Cleanup" -Message "Script is exiting but $MountDir is not empty; Dismount failed:"
                Write-Output -InputObject $_
                Out-Log @Preamble -Section "Cleanup" -Message "Exiting with code 3010 to trigger a soft reboot"
                $STAction = New-ScheduledTaskAction -Execute "powershell.exe" `
                    -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -command "& {Get-WindowsImage -Mounted | Where-Object {$_.MountStatus -eq ''Invalid''} | ForEach-Object {$_ | Dismount-WindowsImage -Discard -ErrorVariable wimerr; if ([bool]$wimerr) {$errflag = $true}}; If (-not $errflag) {Clear-WindowsCorruptMountPoint; Unregister-ScheduledTask -TaskName ''CleanupWIM'' -Confirm:$false}}"'
                $STTrigger = New-ScheduledTaskTrigger -AtStartup
                Register-ScheduledTask -Action $STAction `
                    -Trigger $STTrigger `
                    -TaskName "CleanupWIM" `
                    -Description "Clean up WIM Mount point that failed to dismount: $MountDir" `
                    -User "NT AUTHORITY\SYSTEM" `
                    -RunLevel Highest `
                    -Force
                Stop-Transcript -ErrorAction SilentlyContinue 
                exit 3010
            }
        }
        if ((Get-ChildItem $MountDir).count -le 0) { 
            try {
                Remove-Item -Path $MountDir
            }
            catch {
                Out-Log @Preamble -Section "Cleanup" -Message "Script is exiting, failed to remove $MountDir; Directory is empty but still failed:"
                Write-Output -InputObject $_
                Out-Log @Preamble -Section "Cleanup" -Message "Exiting with code 3010 to trigger a soft reboot"
                $STAction = New-ScheduledTaskAction -Execute "powershell.exe" `
                    -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -command "& {Get-WindowsImage -Mounted | Where-Object {$_.MountStatus -eq ''Invalid''} | ForEach-Object {$_ | Dismount-WindowsImage -Discard -ErrorVariable wimerr; if ([bool]$wimerr) {$errflag = $true}}; If (-not $errflag) {Clear-WindowsCorruptMountPoint; Unregister-ScheduledTask -TaskName ''CleanupWIM'' -Confirm:$false}}"'
                $STTrigger = New-ScheduledTaskTrigger -AtStartup
                Register-ScheduledTask -Action $STAction `
                    -Trigger $STTrigger `
                    -TaskName "CleanupWIM" `
                    -Description "Clean up WIM Mount point that failed to dismount: $MountDir" `
                    -User "NT AUTHORITY\SYSTEM" `
                    -RunLevel Highest `
                    -Force
                Stop-Transcript -ErrorAction SilentlyContinue 
                exit 3010
            }
        }
    } else {
        Stop-Transcript -ErrorAction SilentlyContinue 
        exit $ExitCode
    }
}

# Startup - Ensure a few prerequisites are in order
Start-Transcript $MainLogDir -Append
if (-not $JavaPath) {
    $JavaList=@()
    Get-Item -Path $ProgramList | ForEach-Object -Process {
        if ($PSItem.GetValue('DisplayName') -like "*Java*") {
            $JavaList+=@{
                DisplayName=$PSItem.GetValue('DisplayName');
                InstallDate=$PSItem.GetValue('InstallDate');
                InstallLocation=$PSItem.GetValue('InstallLocation');
                Version=$PSItem.GetValue('Version');
                MSICode=$PSItem.PSChildName;
            }
        }
    }
    $JavaPath=($JavaList | `
        Where-Object -Property DisplayName -NotLike "*Development Kit*" |` # Filter out any instances that aren't JRE
        Where-Object -Property 'InstallLocation' -NE $null | ` # Filter out the Java Updater
        Sort-Object -Descending -Property 'Version' ` # Find the most recent version
    )[0]
    $JavaPath=$JavaPath.InstallLocation;
    Remove-Variable -Name JavaList
    Out-Log @Preamble -Section "Pregen" -Message "`$JavaPath was empty; choosing newest Java version: $JavaPath"
} else { Out-Log @Preamble -Section "Pregen" -Message "JavaPath provided as $JavaPath"}

if ((Test-Path $MountDir) -and ((Get-ChildItem $MountDir).count -gt 0)) {
    Out-Log @Preamble -Section "Pregen" -Message "Mount directory $MountDir is not empty. Another installation failed or is in progress."
    Clean-WindowsImage -ExitCode 1 ;
}
Out-Log @Preamble -Section "Start" -Message "PowerShell WIM installer for $ApplicationName"

try {
    Out-Log @Preamble -Section "Pregen" -Message "Creating directory for mount at $MountDir"
    New-Item -Path $MountDir -ItemType Directory -ErrorAction Continue
    Out-Log @Preamble -Section "Pregen" -Message "Mounting $ApplicationName at $MountDir"
    Mount-WindowsImage -ImagePath "$PSScriptRoot\$ApplicationName"_$DateVer.wim -Path $MountDir -Index 1 -LogPath $MountLogDir
    Get-WindowsImage -Mounted
}
catch {
    Out-Log -Preamble @Preamble -Section "Start" -Message "Error mounting .wim:"
    Write-Output $_
    Clean-WindowsImage -ExitCode 1
}

#Installation
try {
    Out-Log -Preamble @Preamble -Section "Generate" -Message "Adjusting Local\NXLocal XMLs:"
    if ((Get-Item $ProgramList).pschildname -contains '{DA3E3F18-6E40-492E-9EDD-49D7C2A0F0BD}') {
        Out-Log -Preamble @Preamble -Section "Generate" -Message "NX is installed; using NX XML as base"
        $content=Get-Content -Path $MountDir\Local.xml -Verbose
        Out-File -InputObject $content.Replace('C:\\Program Files\\PayDay\\',($MountDir).Replace('\','\\')).Replace('C:/Program Files/PayDay/',($MountDir).Replace('\','/')) -FilePath $PSScriptRoot\edit.xml -Verbose -Encoding utf8
    } else {
        Out-Log -Preamble @Preamble -Section "Generate" -Message "Using Non-NX XML as base"
        $content=Get-Content -Path $MountDir\TCLocalNoNX.xml -Verbose
        Out-File -InputObject $content.Replace('C:\\Program Files\\PayDay\\',($MountDir).Replace('\','\\')).Replace('C:/Program Files/PayDay/',($MountDir).Replace('\','/')) -FilePath $PSScriptRoot\edit.xml -Verbose -Encoding utf8
    }
    try {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Running Tem.bat"
        Start-Process -FilePath "$MountDir\Tc12.4.0_patch_5_wntx64\wntx64\tem.bat" -ArgumentList @("-jre `"$JavaPath`"","-s `"$PSScriptRoot\edit.xml`"") -Wait -Verbose -NoNewWindow
        Start-Sleep -Seconds 10;
    }
    catch {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Error running Tem.bat:"
        Write-Output -InputObject $_
        Clean-WindowsImage -ExitCode 11
    }
    try {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Running Visualization Installer"
        Start-Process -FilePath "$MountDir\TcVis_12405_win64.exe" -ArgumentList '/quiet' -Wait -Verbose -NoNewWindow
        Start-Sleep -Seconds 10
    }
    catch {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Error installing TC Visualization:"
        Write-Output
        Clean-WindowsImage -ExitCode 12
    }
    Out-Log -Preamble @Preamble -Section "Install" -Message "Copying icons"
    Copy-Item -Path "$MountDir\Icons\*" -Destination "C:\Program Files\Siemens\Teamcenter12\portal\plugins\configuration_12000.4.0\" -Force -Verbose -Recurse
    Out-Log -Preamble @Preamble -Section "Install" -Message "Refreshing Viewer"
    Start-Process -FilePath "C:\Program Files\Siemens\Teamcenter12\portal\registry\genregxml.bat" -Verbose -Wait -NoNewWindow
    Out-Log -Preamble @Preamble -Section "Install" -Message "Copying Shortcut"
    Copy-Item -Path "$MountDir\Teamcenter 12.lnk" -Destination "C:\Users\Public\Desktop\" -Verbose -Force
    try {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Writing AWOAI Data to Registry"
        # Reg2CI (c) 2021 by Roger Zander
        if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\.awoai") -ne $true) {
            New-Item "HKLM:\SOFTWARE\Classes\.awoai" -Force
        }
        if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\awoai_auto_file\shell\open\command") -ne $true) {
            New-Item "HKLM:\SOFTWARE\Classes\awoai_auto_file\shell\open\command" -Force
        }
        New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\.awoai' -Name '(default)' -Value 'awoai_auto_file' -PropertyType String -Force;
        New-ItemProperty -LiteralPats 'HKLM:\SOFTWARE\Classes\awoai_auto_file\shell\open\command' -Name '(default)' -Value '\"C:\Program Files (x86)\Siemens\Teamcenter\WSLauncheri\TcClientAppLauncher.exe\" \"%1\' -PropertyType String -Force;
    }
    catch {
        Out-Log -Preamble @Preamble -Section "Install" -Message "Error writing to registry:"
        Write-Output -InputObject $_
        Out-Log -Preamble @Preamble -Section "Install" -Message "Trying to import reg file instead..."
        try {
            reg import "$MountDir/AwoaiRegistry.reg"
        }
        catch {
            Out-Log -Preamble @Preamble -Section "Install" -Message "All tries to write AWOAI data to Registry failed."
            Write-Output -InputObject $_
            Clean-WindowsImage -ExitCode 13
        }
    }
    $retCode=0
}
catch {
    Out-Log -Preamble @Preamble -Section "Install" -Message "Failed to install ${ApplicationName}:"
    Write-Output $_
    $retCode=1
}
finally {
    Out-Log -Preamble @Preamble -Section "Exiting" -Message "Trying to dismount WIM"
    Clean-WindowsImage -ExitCode $retCode
    exit $retCode
}