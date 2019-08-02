<#
.SYNOPSIS
A PowerShell GUI requesting a user's cell phone number and carrier
then outputting that result to an OSD Task Sequence.

.NOTES
Written By: Nathan Ziehnert (@theznerd)
Version: 1.0
ChangeLog:
 - 1.0: Initial Release

.LINK
https://z-nerd.com/
(PoSHPF) https://github.com/theznerd/PoSHPF

.DESCRIPTION
A PowerShell GUI requesting a user's cell phone number and carrier
then outputting that result to an OSD Task Sequence. This script is
best paired with Send-Notification.ps1 during a task sequence to
notify a user via SMS that an upgrade is completed.

This GUI makes use of PoSHPFv1.2.

.PARAMETER LogFile
By providing a log file path you enable file logging. This log file is
a CMTrace compatible log file.

.PARAMETER SettingsFile
The path to the settings file you wish to read from. Defaults to a file
named "settings.ini" in the root of the script folder.

.PARAMETER MaxRuntime
The maximum time you want the script to wait for user input before exiting
and continuing the task seqeunce. The default time period is 10 minutes / 
600 seconds.
#>
[cmdletbinding()]
param(
    [string]$LogFile,
    [string]$SettingsFile="$PSScriptRoot\Settings.ini",
    [int]$maxRuntime=600
)
$Debug = $false
$Logging = $false
$Verbose = $false
if($DebugPreference -ne "SilentlyContinue"){ $Debug = $true }
if($VerbosePreference -ne "SilentlyContinue"){ $Verbose = $true }
if($LogFile){ $Logging = $true }

Set-Variable -Name maxRuntime -Scope Script

#Import Z-Nerd Modules and Load Settings
Import-Module "$PSScriptRoot\Resources\ZNerdFunctions.psm1" -Force
Write-ZNLogs -Description "Loaded Z-Nerd Modules" -Source "Initializaiton" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
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

#Validate Settings
if($settings["BaseTheme"] -eq "" -or $null -eq $settings["BaseTheme"])
{
    Write-ZNLogs -Description "Base theme not set, assuming `"Light`"" -Source "Initializaiton" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    $settings["BaseTheme"] = "Light"
}
if($settings["AccentColor"] -eq "" -or $null -eq $settings["AccentColor"])
{
    Write-ZNLogs -Description "Base theme not set, assuming `"Cobalt`"" -Source "Initializaiton" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    $settings["AccentColor"] = "Cobalt"
}
if(     $settings["NotificationTitle"] -eq ""    `
    -or $null -eq $settings["NotificationTitle"] `
    -or $settings["NotificationMessage"] -eq ""    `
    -or $null -eq $settings["NotificationMessage"] `
    -or $settings["MobileNumberLabel"] -eq ""    `
    -or $null -eq $settings["MobileNumberLabel"] `
    -or $settings["MobileCarrierLabel"] -eq ""    `
    -or $null -eq $settings["MobileCarrierLabel"] `
    -or $settings["StandardCarrierMessageLabel"] -eq ""    `
    -or $null -eq $settings["StandardCarrierMessageLabel"] `
    -or $settings["NotifyMeButtonText"] -eq ""    `
    -or $null -eq $settings["NotifyMeButtonText"] `
    -or $settings["CancelMeButtonText"] -eq ""    `
    -or $null -eq $settings["CancelMeButtonText"])
{
    Write-ZNLogs -Description "One or more localization strings are missing. Please check NotificationTitle, NotificationMesage, MobileNumberLabel, MobileCarrierLabel, StandardCarrierMessageLabel, NotifyMeButtonText, and CancelMeButtonText in the settings file." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
}

Write-ZNLogs -Description "Loading the PoSHPF Framework." -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
## BEGIN POSHPF
#region PoSHPF
# PoSHPF - Version 1.2
# Grab all resources (MahApps, etc), all XAML files, and any potential static resources
$Global:resources = Get-ChildItem -Path "$PSScriptRoot\Resources\*.dll" -ErrorAction SilentlyContinue
$Global:XAML = Get-ChildItem -Path "$PSScriptRoot\XAML\*.xaml" -ErrorAction SilentlyContinue
$Global:MediaResources = Get-ChildItem -Path "$PSScriptRoot\Media" -ErrorAction SilentlyContinue

# This class allows the synchronized hashtable to be available across threads,
# but also passes a couple of methods along with it to do GUI things via the
# object's dispatcher.
class SyncClass 
{
    #Hashtable containing all forms/windows and controls - automatically created when newing up
    [hashtable]$SyncHash = [hashtable]::Synchronized(@{}) 
    
    # method to close the window - pass window name
    [void]CloseWindow($windowName){ 
        $this.SyncHash.$windowName.Dispatcher.Invoke([action]{$this.SyncHash.$windowName.Close()},"Normal") 
    }
    
    # method to update GUI - pass object name, property and value   
    [void]UpdateElement($object,$property,$value){ 
        $this.SyncHash.$object.Dispatcher.Invoke([action]{ $this.SyncHash.$object.$property = $value },"Normal") 
    } 
}
$Global:SyncClass = [SyncClass]::new() # create a new instance of this SyncClass to use.

###################
## Import Resources
###################
# Load WPF Assembly
Add-Type -assemblyName PresentationFramework

# Load Resources
foreach($dll in $resources) { [System.Reflection.Assembly]::LoadFrom("$($dll.FullName)") | out-null }

##############
## Import XAML
##############
$xp = '[^a-zA-Z_0-9]' # All characters that are not a-Z, 0-9, or _
$vx = @()             # An array of XAML files loaded

foreach($x in $XAML) { 
    # Items from XAML that are known to cause issues
    # when PowerShell parses them.
    $xamlToRemove = @(
        'mc:Ignorable="d"',
        "x:Class=`"(.*?)`"",
        "xmlns:local=`"(.*?)`""
    )

    $xaml = Get-Content $x.FullName # Load XAML
    $xaml = $xaml -replace "x:N",'N' # Rename x:Name to just Name (for consumption in variables later)
    foreach($xtr in $xamlToRemove){ $xaml = $xaml -replace $xtr } # Remove items from $xamlToRemove
    
    # Create a new variable to store the XAML as XML
    New-Variable -Name "xaml$(($x.BaseName) -replace $xp, '_')" -Value ($xaml -as [xml]) -Force
    
    # Add XAML to list of XAML documents processed
    $vx += "$(($x.BaseName) -replace $xp, '_')"
}

#######################
## Add Media Resources
#######################
$imageFileTypes = @(".jpg",".bmp",".gif",".tif",".png") # Supported image filetypes
$avFileTypes = @(".mp3",".wav",".wmv") # Supported audio/visual filetypes
$xp = '[^a-zA-Z_0-9]' # All characters that are not a-Z, 0-9, or _
if($MediaResources.Count -gt 0){
    ## Okay... the following code is just silly. I know
    ## but hear me out. Adding the nodes to the elements
    ## directly caused big issues - mainly surrounding the
    ## "x:" namespace identifiers. This is a hacky fix but
    ## it does the trick.
    foreach($v in $vx)
    {
        $xml = ((Get-Variable -Name "xaml$($v)").Value) # Load the XML

        # add the resources needed for strings
        $xml.DocumentElement.SetAttribute("xmlns:sys","clr-namespace:System;assembly=System")

        # if the document doesn't already have a "Window.Resources" create it
        if($null -eq ($xml.DocumentElement.'Window.Resources')){ 
            $fragment = "<Window.Resources>" 
            $fragment += "<ResourceDictionary>"
        }
        
        # Add each StaticResource with the key of the base name and source to the full name
        foreach($sr in $MediaResources)
        {
            $srname = "$($sr.BaseName -replace $xp, '_')$($sr.Extension.Substring(1).ToUpper())" #convert name to basename + Uppercase Extension
            if($sr.Extension -in $imageFileTypes){ $fragment += "<BitmapImage x:Key=`"$srname`" UriSource=`"$($sr.FullName)`" />" }
            if($sr.Extension -in $avFileTypes){ 
                $uri = [System.Uri]::new($sr.FullName)
                $fragment += "<sys:Uri x:Key=`"$srname`">$uri</sys:Uri>" 
            }    
        }

        # if the document doesn't already have a "Window.Resources" close it
        if($null -eq ($xml.DocumentElement.'Window.Resources'))
        {
            $fragment += "</ResourceDictionary>"
            $fragment += "</Window.Resources>"
            $xml.DocumentElement.InnerXml = $fragment + $xml.DocumentElement.InnerXml
        }
        # otherwise just add the fragment to the existing resource dictionary
        else
        {
            $xml.DocumentElement.'Window.Resources'.ResourceDictionary.InnerXml += $fragment
        }

        # Reset the value of the variable
        (Get-Variable -Name "xaml$($v)").Value = $xml
    }
}

#################
## Create "Forms"
#################
$forms = @()
foreach($x in $vx)
{
    $Reader = (New-Object System.Xml.XmlNodeReader ((Get-Variable -Name "xaml$($x)").Value)) #load the xaml we created earlier into XmlNodeReader
    New-Variable -Name "form$($x)" -Value ([Windows.Markup.XamlReader]::Load($Reader)) -Force #load the xaml into XamlReader
    $forms += "form$($x)" #add the form name to our array
    $SyncClass.SyncHash.Add("form$($x)", (Get-Variable -Name "form$($x)").Value) #add the form object to our synched hashtable
}

#################################
## Create Controls (Buttons, etc)
#################################
$controls = @()
$xp = '[^a-zA-Z_0-9]' # All characters that are not a-Z, 0-9, or _
foreach($x in $vx)
{
    $xaml = (Get-Variable -Name "xaml$($x)").Value #load the xaml we created earlier
    $xaml.SelectNodes("//*[@Name]") | %{ #find all nodes with a "Name" attribute
        $cname = "form$($x)Control$(($_.Name -replace $xp, '_'))"
        Set-Variable -Name "$cname" -Value $SyncClass.SyncHash."form$($x)".FindName($_.Name) #create a variale to hold the control/object
        $controls += (Get-Variable -Name "form$($x)Control$($_.Name)").Name #add the control name to our array
        $SyncClass.SyncHash.Add($cname, $SyncClass.SyncHash."form$($x)".FindName($_.Name)) #add the control directly to the hashtable
    }
}

############################
## FORMS AND CONTROLS OUTPUT
############################
Write-Host -ForegroundColor Cyan "The following forms were created:"
$forms | %{ Write-Host -ForegroundColor Yellow "  `$$_"} #output all forms to screen
if($controls.Count -gt 0){
    Write-Host ""
    Write-Host -ForegroundColor Cyan "The following controls were created:"
    $controls | %{ Write-Host -ForegroundColor Yellow "  `$$_"} #output all named controls to screen
}

#######################
## DISABLE A/V AUTOPLAY
#######################
foreach($x in $vx)
{
    $carray = @()
    $fts = $syncClass.SyncHash."form$($x)"
    foreach($c in $fts.Content.Children)
    {
        if($c.GetType().Name -eq "MediaElement") #find all controls with the type MediaElement
        {
            $c.LoadedBehavior = "Manual" #Don't autoplay
            $c.UnloadedBehavior = "Stop" #When the window closes, stop the music
            $carray += $c #add the control to an array
        }
    }
    if($carray.Count -gt 0)
    {
        New-Variable -Name "form$($x)PoSHPFCleanupAudio" -Value $carray -Force # Store the controls in an array to be accessed later
        $syncClass.SyncHash."form$($x)".Add_Closed({
            foreach($c in (Get-Variable "form$($x)PoSHPFCleanupAudio").Value)
            {
                $c.Source = $null #stops any currently playing media
            }
        })
    }
}

#####################
## RUNSPACE FUNCTIONS
#####################
## Yo dawg... Runspace to clean up Runspaces
## Thank you Boe Prox / Stephen Owen
#region RSCleanup
$Script:JobCleanup = [hashtable]::Synchronized(@{}) 
$Script:Jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList)) #hashtable to store all these runspaces

$jobCleanup.Flag = $True #cleanup jobs
$newRunspace =[runspacefactory]::CreateRunspace() #create a new runspace for this job to cleanup jobs to live
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup) #pass the jobCleanup variable to the runspace
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) #pass the jobs variable to the runspace
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {    
        Foreach($runspace in $jobs) {            
            If ($runspace.Runspace.isCompleted) {                         #if runspace is complete
                [void]$runspace.powershell.EndInvoke($runspace.Runspace)  #then end the script
                $runspace.powershell.dispose()                            #dispose of the memory
                $runspace.Runspace = $null                                #additional garbage collection
                $runspace.powershell = $null                              #additional garbage collection
            } 
        }
        #Clean out unused runspace jobs
        $temphash = $jobs.clone()
        $temphash | Where {
            $_.runspace -eq $Null
        } | ForEach {
            $jobs.remove($_)
        }        
        Start-Sleep -Seconds 1 #lets not kill the processor here 
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $newRunspace
$jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke() 
#endregion RSCleanup

#This function creates a new runspace for a script block to execute
#so that you can do your long running tasks not in the UI thread.
#Also the SyncClass is passed to this runspace so you can do UI
#updates from this thread as well.
function Start-BackgroundScriptBlock($scriptBlock){
    $newRunspace =[runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"
    $newRunspace.ThreadOptions = "ReuseThread"          
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("SyncClass",$SyncClass) 
    $PowerShell = [PowerShell]::Create().AddScript($scriptBlock)
    $PowerShell.Runspace = $newRunspace

    #Add it to the job list so that we can make sure it is cleaned up
    [void]$Jobs.Add(
        [pscustomobject]@{
            PowerShell = $PowerShell
            Runspace = $PowerShell.BeginInvoke()
        }
    )
}
#endregion PoSHPF

########################
## WIRE UP YOUR CONTROLS
########################
# Set the theme for the windows from Settings INI
foreach($form in $forms)
{
    $f = (Get-Variable -Name "$form").Value
    Write-ZNLogs -Description "Setting theme from settings." -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    try{
        $void = [MahApps.Metro.ThemeManager]::ChangeTheme($f, [MahApps.Metro.ThemeManager]::GetTheme("$($settings["BaseTheme"]).$($settings["AccentColor"])"))
    }catch{
        Write-ZNLogs -Description "Error setting the theme. The error was: $($Error[0].Exception)." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    }
}

# Localization
Write-ZNLogs -Description "Setting localization text." -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
$formUpdateNotifier.Title = $settings["NotificationTitle"]
$formUpdateNotifierControlNotificationMessage.Text = $settings["NotificationMessage"]
$formUpdateNotifierControlMobileNumberLabel.Content = $settings["MobileNumberLabel"]
$formUpdateNotifierControlMobileCarrierLabel.Content = $settings["MobileCarrierLabel"]
$formUpdateNotifierControlCarrierRatesLabel.Content = $settings["StandardCarrierMessageLabel"]
$formUpdateNotifierControlNotifyMe.Content = $settings["NotifyMeButtonText"]
$formUpdateNotifierControlCancelMe.Content = $settings["CancelMeButtonText"]

# Load up the available cell providers
Write-ZNLogs -Description "Loading Mobile Providers." -Source "Initializaiton" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
try{
    $MobileProviders = Import-Csv -Path "$PSScriptRoot\SupportedMobileProviders.csv" | Where-Object {-not ([string]::IsNullOrEmpty($_.Enabled))}
}catch{
    Write-ZNLogs -Description "Error loading mobile providers. Error was: $($Error[0].Exception)" -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Exit
}
if($MobileProviders.Count -lt 1){
    Write-ZNLogs -Description "No mobile providers enabled. Check `"$PSScriptRoot\SupportedMobileProviders.csv`" to ensure you have enabled any." -Source "Initializaiton" -Level 3 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    Exit
}

# Create the items for the provider dropdown
$ProviderSelect = @()
foreach($mp in $MobileProviders)
{
    $ProviderSelect += [pscustomobject]@{Name = "$($mp.MobileProvider)"; Value = "$($mp.EmailSuffix)"}
}
$formUpdateNotifierControlMobileCarrierSelect.ItemsSource = $ProviderSelect
$formUpdateNotifierControlMobileCarrierSelect.DisplayMemberPath = "Name"

# Load the TSEnvironment
try{
    $ts = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch{
    Write-ZNLogs -Description "Error loading TS Environment. Assuming debug mode outside of Task Sequence." -Source "Initializaiton" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    $debugGUI = $True
}

# Fires when the NotifyMe button is clicked
$formUpdateNotifierControlNotifyMe.Add_Click({
    Write-ZNLogs -Description "Notify Me button clicked" -Source "Execution" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    $pn = $formUpdateNotifierControlMobileNumberInput.Text -replace '[^\d]','' #we only want numbers

    #Validate the user selected a carrier AND they have a 10 digit number
    if($null -eq $formUpdateNotifierControlMobileCarrierSelect.SelectedItem -or $pn -notmatch '^\d{10}$')
    {
        Write-ZNLogs -Description "User attempted to submit incomplete info." -Source "Execution" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        [System.Windows.MessageBox]::Show("Please check that you have entered a 10 digit number and that you have selected your carrier.")
        return
    }

    # If we're not debugging (TSEnvironment exists), run this code
    if(!$debugGUI)
    {
        Write-ZNLogs -Description "Outputting variables to OSDTS environment." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        
        #Set OSDTS variables
        $ts.Value("OSDUCNNotify") = $true
        $ts.Value("OSDUCNEmail") = "$pn@$($formUpdateNotifierControlMobileCarrierSelect.SelectedItem.Value)"
        $ts.Value("OSDUCNMob") = $pn
        Write-ZNLogs -Description "Exiting..." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        
        #Close the form
        $formUpdateNotifier.Close()
    }

    # If we're debugging, run this code
    else{
        Write-ZNLogs -Description "Outputting variables to console." -Source "Execution" -Level 1 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
        
        #Write the three important pieces of info out to the console for debugging purposes
        Write-Host "Mobile Number is: $pn"
        Write-Host "Mobile Carrier is: $($formUpdateNotifierControlMobileCarrierSelect.SelectedItem.Name)"
        Write-Host "Mobile Email to Text is: $pn@$($formUpdateNotifierControlMobileCarrierSelect.SelectedItem.Value)"
    }
})

# Run if Cancel is pressed
$formUpdateNotifierControlCancelMe.Add_Click({
    Write-ZNLogs -Description "User clicked Cancel button. Exiting..." -Source "Execution" -Level 4 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
    $formUpdateNotifier.Close()
})

# Run this code when the window object is loaded
$formUpdateNotifier.Add_Loaded({
    $script:currentRuntime = 0
    
    # Create a timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]'0:0:1' # 1 second
    
    # Execute this script when the timer interval elapses
    $timer.Add_Tick.Invoke({
        $script:currentRuntime += 1

        #If the timer has exceeded the maxruntime, then exit the script
        if($script:currentRuntime -ge $script:maxRuntime)
        {
            Write-ZNLogs -Description "User didn't answer within $script:maxRuntime seconds. Exiting..." -Source "Execution" -Level 2 -FileLogging:$Logging -LogFilePath:$LogFile -Debugging:$Debug -Verbose:$Verbose
            $formUpdateNotifier.Close()
            $timer.Stop()
        }
    })
    $timer.Start()
})

############################
###### DISPLAY DIALOG ######
############################
[void]$formUpdateNotifier.ShowDialog()

##########################
##### SCRIPT CLEANUP #####
##########################
$jobCleanup.Flag = $false #Stop Cleaning Jobs
$jobCleanup.PowerShell.Runspace.Close() #Close the runspace
$jobCleanup.PowerShell.Dispose() #Remove the runspace from memory