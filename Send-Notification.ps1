<#
.SYNOPSIS
A PowerShell script to send notifications to mobile devices.

.NOTES
Written By: Nathan Ziehnert (@theznerd)
Version: 1.1
ChangeLog:
 - 1.1: Bug fix for email - uploaded wrong version.
 - 1.0: Initial Release

.LINK
https://z-nerd.com/

.DESCRIPTION
A PowerShell script to send notifications to mobile devices either via
email to SMS relay (from each telephone provider) or to send the message
and mobile device number to an Azure endpoint for Flow or Logic Apps.

.PARAMETER mobileNumber
The mobile number associated with the device. Used only for the Azure
service - this number will be sent to the Azure endpoint via POST JSON
with the property name PN.

.PARAMETER mobileEmail
The full mobile email address associated with the device (e.g. 
3035551234@tmomail.net for a T-Mobile device with the number 3035551234).
A decently long list of email to SMS relays is available here:
https://support.teamunify.com/en/articles/227-communication-email-to-sms-gateway-list

.PARAMETER LogFile
By providing a log file path you enable file logging. This log file is
a CMTrace compatible log file.

.PARAMETER SettingsFile
The path to the settings file you wish to read from. Defaults to a file
named "settings.ini" in the root of the script folder.
#>
[cmdletbinding()]
param(
    [string]$mobileNumber,
    [string]$mobileEmail,
    [string]$LogFile,
    [string]$SettingsFile="$PSScriptRoot\Settings.ini"
)
#Define our logging output
$Debug = $false 
$Logging = $false
$Verbose = $false
if($DebugPreference -ne "SilentlyContinue"){ $Debug = $true }
if($VerbosePreference -ne "SilentlyContinue"){ $Verbose = $true }
if($LogFile){ $Logging = $true }

#Load custom modules
Import-Module "$PSScriptRoot\Resources\ZNerdFunctions.psm1" -Force
Write-ZNLogs -Description "Loaded Z-Nerd Modules" -Source "Initializaiton" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose

#Load the settings file
Write-ZNLogs -Description "Loading Settings from $SettingsFile" -Source "Initializaiton" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
try
{
    $settings = Get-ZNSettings -SettingsINI "$SettingsFile"
    Write-ZNLogs -Description "Loaded Settings from $SettingsFile" -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
}
catch
{
    Write-ZNLogs -Description "Failed to load $SettingsFile. Error was: $($Error[0].Exception)" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Exit
}

#Check to make sure either mobileNumber of mobileEmail is set properly
if(($null -eq $mobileNumber -or $mobileNumber -eq "" -and $settings["Service"] -eq "Azure") -or ($null -eq $mobileEmail -or $mobileEmail -eq "" -and $settings["Service"] -eq "Mail"))
{
    If($settings["Service"] -eq "Azure")
    {
        Write-ZNLogs -Description "You need to set `$mobileNumber" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    }
    else
    {
        Write-ZNLogs -Description "You need to set `$mobileEmail" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    }
    Exit
}

## All of this section if settings is configured for e-mail
if($settings["Service"] -eq "Mail")
{
    #Confirm we have the data that we need
    if($settings["MailServer"] -eq "" -or $null -eq $settings["MailServer"])
    {
        Write-ZNLogs -Description "No mail server configured. Check settings file!" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    };
    if($settings["MailPort"] -eq "" -or $null -eq $settings["MailPort"])
    {
        Write-ZNLogs -Description "No mail port configured. Assuming port 25." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        $settings["MailPort"] = 25
    }
    if($settings["MailSSL"] -eq "" -or $null -eq $settings["MailSSL"])
    {
        Write-ZNLogs -Description "No SSL setting configured. Assuming not SSL." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        $settings["MailSSL"] = $false
    }
    if($settings["MailFrom"] -eq "" -or $null -eq $settings["MailFrom"])
    {
        Write-ZNLogs -Description "No from address configured. Check settings file!" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }
    if($settings["MailSubject"] -eq "" -or $null -eq $settings["MailSubject"])
    {
        Write-ZNLogs -Description "No subject configured. Check settings file!" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }

    #Write some logging information
    Write-ZNLogs -Description "Mail Server is: $($settings["MailServer"])" -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Write-ZNLogs -Description "Mail Port is: $($settings["MailPort"])" -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Write-ZNLogs -Description "Mail is sending over SSL: $($settings["MailSSL"])" -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Write-ZNLogs -Description "Mail is being sent from: $($settings["MailFrom"])" -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose

    #Review the Username and password settings
    if(($null -ne $settings["MailUsername"] -and $settings["MailUsername"] -ne "") -ne ($null -ne $settings["MailPassword"] -and $settings["MailPassword"] -ne ""))
    {
        Write-ZNLogs -Description "You must set both the username and password for email if you choose to use them." -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }
    if(($null -ne $settings["MailUsername"] -and $settings["MailUsername"] -ne "") -and ($null -ne $settings["MailPassword"] -and $settings["MailPassword"] -ne ""))
    {
        Write-ZNLogs -Description "Mail username and password detected. This is an insecure method and should only be used for testing purposes. It is recommended that you configure an alias on your mail server which has permissions to be sent from any user." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        $password = ConvertTo-SecureString $settings["MailPassword"] -AsPlainText -Force
        $MailCredential = New-Object System.Management.Automation.PSCredential ($settings["MailUsername"], $password)
    }

    #Generate the mail item
    $mm = @{
        To = $mobileEmail
        From = $settings["MailFrom"]
        Subject = $settings["MailSubject"]
        SmtpServer = $settings["MailServer"]
        Port = $settings["MailPort"]
        Body = $settings["Message"]
        UseSsl = $settings["MailSSL"]    
    }
    if($null -ne $MailCredential){$mm.Add('Credential',$MailCredential)}
    
    #Send the mail message
    Write-ZNLogs -Description "Sending mail message." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    try
    {
        Send-MailMessage @mm
        Write-ZNLogs -Description "Successfully sent mail message." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    }
    catch
    {
        Write-ZNLogs -Description "Something went wrong when sending the mail message. The error was: $($Error[0].Exception)" -Source "Execution" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }
    
}

## All of this section if settings is configured for Azure
elseif($settings["Service"] -eq "Azure")
{
    #Validate our settings
    if($settings["AzureEndpoint"] -eq "" -or $null -eq $settings["AzureEndpoint"])
    {
        Write-ZNLogs -Description "Azure Endpoint is not set. Check settings file!" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }

    #Create the data to send
    $d = @{
        pn = $mobileNumber
        message = $settings["Message"]
    }

    #Invoke the web request and send data ($d) to azure endpoint via POST
    try{
        Write-ZNLogs -Description "Invoking web request." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Invoke-WebRequest -UseBasicParsing $settings["AzureEndpoint"] -ContentType "application/json" -Method POST -Body "$($d | ConvertTo-Json)"
        Write-ZNLogs -Description "Successfully sent web request to the Azure Endpoint!" -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    }
    catch{
        Write-ZNLogs -Description "Sending the POST request to the Azure endpoint failed. The error was: $($Error[0].Exception)" -Source "Execution" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        Exit
    }
}

# Catch any weirdos trying to do something other than mail or azure
else
{
    Write-ZNLogs -Description "Hmm... I don't support anything other than Mail or Azure at the moment. Please check settings file." -Source "Initialization" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Exit
}
