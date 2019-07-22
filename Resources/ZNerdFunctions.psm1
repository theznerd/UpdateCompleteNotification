function Get-ZNSettings
{
    param(
        # Setting INI to load
        [Parameter(Mandatory=$true)]
        [String]
        $SettingsINI,

        # Delimeter (if not =)
        [Parameter(Mandatory=$false)]
        [String]
        $Delimeter = "=",

        # Comment Character (if not ;)
        [Parameter(Mandatory=$false)]
        [String]
        $CommentCharacter = ";"
    )
    if(Test-Path $SettingsINI)
    {
        [array]$settingsArray = Get-Content -Path $SettingsINI | Where-Object {($_ -ne "") -and (-not $_.StartsWith(';'))}
        $settingsHash = @{}
        foreach($s in $settingsArray)
        {
            $removeComments = $s.Split($CommentCharacter)
            $s = $removeComments[0].Split($Delimeter)
            if($s[1] -eq "true")
            {
                $settingsHash.Add($s[0],$true)
            }
            elseif($s[1] -eq "false")
            {
                $settingsHash.Add($s[0],$false)
            }
            elseif($s[1] -match "^[\d\.]+$")
            {
                $settingsHash.Add($s[0],$s[1] -as (Invoke-Expression "$($s[1])").GetType())
            }
            else
            {
                $text = (($s[1..$($s.Count-1)]) -join "$Delimeter").Replace("`"","```"")
                $settingsHash.Add($s[0],(Invoke-Expression "`"$text`""))
            }
        }
    }
    else
    {
        Throw "Settings INI file does not exist. Please check path"
    }
    return $settingsHash
}

function Write-ZNLogs 
{
    <#
    .SYNOPSIS
    Creates a log entry in all applicable logs (CMTrace compatible File and Verbose logging).
    #>
    [CmdletBinding()]
    Param
    (
        # Log File Enabled
        [Parameter()]
        [switch]
        $FileLogging,

        # Log File Path
        [Parameter()]
        [string]
        $LogFilePath,

        # Log Description
        [Parameter(mandatory=$true)]
        [string]
        $Description,

        # Log Source
        [Parameter(mandatory=$true)]
        [string]
        $Source,

        # Log Level
        [Parameter(mandatory=$false)]
        [ValidateRange(1,4)]
        [int]
        $Level,

        # Debugging Enabled
        [Parameter(mandatory=$false)]
        [switch]
        $Debugging
    )
    
    # Get Current Time (UTC)
    $dt = [DateTime]::UtcNow

    $lt = switch($Level)
    {
        1 { 'Informational' }
        2 { 'Warning' }
        3 { 'Error' }
        4 { 'Debug' }
    }

    if($FileLogging)
    {
        # Create Pretty CMTrace Log Entry
        if(($Level -lt 4) -or $Debugging)
        {
            if($Level -ne 1)
            {
                $cmtl  = "<![LOG[`($lt`) $Description]LOG]!>"
            }
            else
            {
                $cmtl  = "<![LOG[$Description]LOG]!>"
            }
            $cmtl += "<time=`"$($dt.ToString('HH:mm:ss.fff'))+000`" "
            $cmtl += "date=`"$($dt.ToString('M-d-yyyy'))`" "
            $cmtl += "component=`"$Source`" "
            $cmtl += "context=`"$($ENV:USERDOMAIN)\$($ENV:USERNAME)`" "
            $cmtl += "type=`"$Level`" "
            $cmtl += "thread=`"$($pid)`" "
            $cmtl += "file=`"`">"
    
            # Write a Pretty CMTrace Log Entry
            $cmtl | Out-File -Append -Encoding UTF8 -FilePath "$LogFilePath"
        }
    }

    if(($Level -lt 4) -or $Debugging)
    {
        if($Level -eq 3)
        {
            Write-Error -Message "[$dt] ($lt) $Source`: $Description"
        }
        elseif(($Level -lt 4 -or $Debugging) -and $VerbosePreference -ne 'SilentlyContinue')
        {
            Write-Verbose -Message "[$dt] ($lt) $Source`: $Description"
        }
    }
}

Export-ModuleMember -Function Write-ZNLogs,Get-ZNSettings