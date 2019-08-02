try{$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment}
catch{$tsenv = $false}
$x64 = [System.Environment]::Is64BitProcess

# TS - In WinPE
if($tsenv -and $tsenv.("_SMSTSInWinPE") -eq "True")
{
    $tsprog = New-Object -ComObject Microsoft.SMS.TSProgressUI
    $tsprog.CloseProgressDialog()
    & "$PSScriptRoot\UserNotification.ps1" -SettingsFile "$PSScriptRoot\Settings.ini" 
}
elseif($tsenv) # TS - Not in WinPE
{
    if($x64)
    {
        Start-Process -Wait -WindowStyle Hidden -FilePath  "$PSScriptRoot\ServiceUI_x64.exe" -ArgumentList "-process:tsprogressui.exe `"c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe`" -ExecutionPolicy Bypass -WindowStyle Hidden -File \`"$PSScriptRoot\UserNotification.ps1\`" -SettingsFile \`"$PSScriptRoot\Settings.ini\`""
    }
    else
    {
        Start-Process -Wait -WindowStyle Hidden -FilePath  "$PSScriptRoot\ServiceUI_x86.exe" -ArgumentList "-process:tsprogressui.exe `"c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe`" -ExecutionPolicy Bypass -WindowStyle Hidden -File \`"$PSScriptRoot\UserNotification.ps1\`" -SettingsFile \`"$PSScriptRoot\Settings.ini\`""
    }    
}
else # Non-TS "Debug"
{
    if($x64)
    {
        Start-Process -Wait -WindowStyle Hidden -FilePath  "$PSScriptRoot\ServiceUI_x64.exe" -ArgumentList "-process:explorer.exe `"c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe`" -ExecutionPolicy Bypass -WindowStyle Hidden -File \`"$PSScriptRoot\UserNotification.ps1\`" -SettingsFile \`"$PSScriptRoot\Settings.ini\`""
    }
    else
    {
        Start-Process -Wait -WindowStyle Hidden -FilePath  "$PSScriptRoot\ServiceUI_x86.exe" -ArgumentList "-process:explorer.exe `"c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe`" -ExecutionPolicy Bypass -WindowStyle Hidden -File \`"$PSScriptRoot\UserNotification.ps1\`" -SettingsFile \`"$PSScriptRoot\Settings.ini\`""
    }
}