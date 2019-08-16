@echo OFF

reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32BIT || set OS=64BIT
if %OS%==64BIT GOTO x64

:x86
"%~dp0ServiceUI_x86.exe" -process:tsprogressui.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0UserNotification.ps1\" -SettingsFile \"%~dp0Settings.ini\"
GOTO end

:x64
"%~dp0ServiceUI_x64.exe" -process:tsprogressui.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0UserNotification.ps1\" -SettingsFile \"%~dp0Settings.ini\"

:end