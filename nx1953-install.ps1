<#
# File: nx1953-install.ps1
# Created: Sunday August 7th 2022
# Author: Nick Strickland
# -----
# Last Modified: Monday, 8th August 2022 12:40:07 am
# ----
# Copright 2022 Nick Strickland, nsstrickland@outlook.com>>
# GNU General Public License v3.0 only - http://www.gnu.org/licenses/gpl-3.0-standalone.html
#>

$ApplicationName="NX1953"
$MountDir = "$PSScriptRoot\$ApplicationName-mount\"
$MainLogDir = "$PSScriptRoot\$ApplicationName-install.log"
$MountLogDir = "$PSScriptRoot\$ApplicationName-mount-action.log"
$Preamble=@{Preamble="InstallScript";LogFile=$MainLogDir}
$ProgramList=@( "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")

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

Start-Transcript $MainLogDir -Append

if ((Test-Path $MountDir) -and ((Get-ChildItem $MountDir).count -gt 0)) {
    Out-Log @Preamble -Section "Start" -Message "Mount directory $MountDir is not empty. Another installation failed or is in progress."
    Clean-WindowsImage -ExitCode 1 ;
}

Out-Log @Preamble -Section "Start" -Message "PowerShell WIM installer for $ApplicationName"

try {
    Out-Log @Preamble -Section "Start" -Message "Creating directory for mount at $MountDir"
    New-Item -Path $MountDir -ItemType Directory -ErrorAction Continue
    Out-Log @Preamble -Section "Start" -Message "Mounting $ApplicationName at $MountDir"
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
    Out-Log -Preamble @Preamble -Section "Install" -Message "Installing $ApplicationName"
    Start-Process -FilePath msiexec.exe `
        -ArgumentList @("/qn",`
            "/norestart",`
            "/L*v $PSScriptRoot\NX1953-base.log",`
            "/I `"$MountDir\SiemensNX-1953_wntx64\nx\SiemensNX.msi`"",`
            "ADDLOCAL=all",`
            "SETUPTYPE=typical",`
            "LICENSESERVER=REDACTED") `
        -Wait `
        -Verbose
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