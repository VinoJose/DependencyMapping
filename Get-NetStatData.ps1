
Param (
[Switch]$NoTaskScheduler
)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
#region functions
function Import-Config {
<#
.Synopsis
   Importing config file.
.DESCRIPTION
   Importing config file and gives output as hash table.
.EXAMPLE
   Import-Config -path c:\temp\Import-Config.config
.EXAMPLE
   Import-Config -path D:\temp\Import-Config.config
.INPUTS
   Import-Config.config
.OUTPUTS
   Configuration table
.NOTES
   None
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   Importing config file and gives output as hash table.
#>
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1',
                  #PositionalBinding=$false,
                  #HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    [OutputType([String])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   ParameterSetName='Parameter Set 1')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $InputObject
    )

    Begin
    {
        $appSettings = @{}
    }
    Process
    {
     foreach ($line in $InputObject) 
        {
        $addNode = $line.Split("=")
        if(($addNode[1]).Contains(‘,’)) 
         {
            $value = ($addNode[1]).Split(‘,’)
            for ($i = 0; $i -lt $value.length; $i++) 
            { 
                $value[$i] = $value[$i].Trim() 
            }
         }
         else 
         {
            $value = $addNode[1].trim(" ")
         }
         $appSettings[$addNode[0].trim(" ")] = $value
        }
    }
    End
    {
        $appSettings
    }
}

function Find-freeDiskSpace {
<#
.Synopsis
   Finds the free space in a drive.
.DESCRIPTION
   This will find the free space in a drive which is given as input. The output will be in percentage.
.EXAMPLE
   Find-freeDiskSpace -DriveLetter
.INPUTS
   Drive Letter
.OUTPUTS
   Free disk space in percentage
.NOTES
   None
.FUNCTIONALITY
   Finds the free space in a drive.
#>
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1',
                  #PositionalBinding=$false,
                  #HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    [OutputType([Int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   ParameterSetName='Parameter Set 1')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $DriveLetter
    )
   
    $DriveDetails = Get-WmiObject -Class win32_logicaldisk | Where-Object {$_.DeviceID -eq $DriveLetter}
    [math]::round($(($DriveDetails.FreeSpace)*100)/$($DriveDetails.Size))
}

function Get-NetStat {
<#
.Synopsis
   Gets Netstat data from local machine.
.DESCRIPTION
   Fetches the current network connections of this computer. Runs the netstat -ano command and gives the output as objects
.EXAMPLE
   Get-NetStat
.INPUTS
   No input is required for this Cmdlet
.OUTPUTS
   Output from this cmdlet is the current network connections of this computer.
.NOTES
   General notes
.FUNCTIONALITY
   Gets Netstat data from local machine.
#>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param()
    Begin {
        Write-Verbose "Fetching the network connection details"
    }    
    Process {
        Write-Verbose "Getting the output of netstat"
        $data = netstat -ano
        $data = $data[4..$data.count]
        foreach ($line in $data)
        {
            if ($line -match "UDP") {
                $line = $line -replace '^\s+', ''
                $line = $line -split '\s+'
            
                Write-Verbose "Defining the properties"
                $properties = @{
                    Protocol = $line[0]
                    LocalIP = ($line[1] -split ":")[0]
                    LocalPort = ($line[1] -split ":")[1]
                    RemoteIP = ($line[2] -split ":")[0]
                    RemotePort = ($line[2] -split ":")[1]
                    State = $null
                    PID = $line[3]
                }
            }
            Else {
                $line = $line -replace '^\s+', ''
                $line = $line -split '\s+'
            
                Write-Verbose "Defining the properties"
                $properties = @{
                    Protocol = $line[0]
                    LocalIP = ($line[1] -split ":")[0]
                    LocalPort = ($line[1] -split ":")[1]
                    RemoteIP = ($line[2] -split ":")[0]
                    RemotePort = ($line[2] -split ":")[1]
                    State = $line[3]
                    PID = $line[4]
                }
            }
                        
            Write-Verbose "Output the current line"
            New-Object -TypeName PSObject -Property $properties
        }
    }
    End {
        Write-Verbose "Completed fetching the network connection details"
    }
}
#endregion

#Importing the input data
Write-Verbose "Importing the input data"
$Data = Get-Content "$ScriptPath\Input.config"
$Table = $Data | Import-Config

if (!(Test-Path $Table.Outputpath)) {
    $null= mkdir $Table.Outputpath
}

#Checking the diskspace avaliable in the drive where outputfile is generated.
Write-Verbose "Checking the diskspace avaliable in the drive where outputfile is generated"
$FreeSpace = Find-freeDiskSpace -DriveLetter $(($Table.Outputpath).Split("\")[0])
if ($FreeSpace -le 5) {
    Write-Output "Disk freespace is less than 5%. Aborting the script"
    break
}

#Building filter to remove the unwanted IP Addresses which is given in the input file.
Write-Verbose "Building filter to remove the unwanted IP Addresses which is given in the input file"
$IPsToExclude = $Table.IPsToExclude
$Filter1  = Foreach ($item in $IPsToExclude) {
"`$_.RemoteIP -ne `"$item`""
}
$Filter = [ScriptBlock]::Create( "$($Filter1 -join " -and ")")

#'if' block will run if the swtich parameter NoTaskScheduler is given during the execution of the script.
if ($NoTaskScheduler) {

    $StartTime = Get-Date     
    Do {
        $Netstat = Get-Netstat
        $CurrentErrorActionPref = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $Output = $Netstat | Where-Object {$_.LocalIP -ne "0.0.0.0" -and $_.LocalIP -ne "127.0.0.1" -and $_.LocalIP -match [ipaddress]$_.LocalIP} |
        Where-Object $Filter |Select-Object -Property *, @{Label = "SiteCode"; e= {$Table.SiteCode}}
        foreach ($item in $Output) {
            $RemoteHostName =  $Null
            $RemoteHostName = [System.Net.Dns]::GetHostEntry($item.RemoteIP).HostName
            if ($RemoteHostName) {
                $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $RemoteHostName
            }
            else {
                $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $Null
            }
        }
        $ErrorActionPreference = $CurrentErrorActionPref    
        if (Test-Path "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv") {
            $Output | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -Append -Encoding ascii
        }
        else {
            $Output | Export-Csv "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -NoTypeInformation   
        } 
        Start-Sleep -Seconds $table.Interval
    } 
    Until (((Get-date) - $StartTime).TotalDays -ge 7 )
}

#'else' block will run if the script is executed using Task Scheduler
else {    
    $Netstat = Get-Netstat
    $CurrentErrorActionPref = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $Output = $Netstat | Where-Object {$_.LocalIP -ne "0.0.0.0" -and $_.LocalIP -ne "127.0.0.1" -and $_.LocalIP -match [ipaddress]$_.LocalIP} |
    Where-Object $Filter |Select-Object -Property *, @{Label = "SiteCode"; e= {$Table.SiteCode}}
    foreach ($item in $Output) {
        $RemoteHostName =  $Null
        $RemoteHostName = [System.Net.Dns]::GetHostEntry($item.RemoteIP).HostName
        if ($RemoteHostName) {
            $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $RemoteHostName
        }
        else {
            $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $Null
        }
    }
    $ErrorActionPreference = $CurrentErrorActionPref    
    if (Test-Path "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv") {
        $Output | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -Append -Encoding ascii
    }
    else {
        $Output | Export-Csv "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -NoTypeInformation   
    }    
}
#Uploading the data to central server
Write-Verbose "Uploading the data to central server"
$Time =  Get-Date 
if ($Time -ge "00:00" -and $Time -le "00:30"){
    Copy-Item -Path "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -Destination "Destinationpath"
    if (!(Test-Path "$($Table.Outputpath)\Archive")){
        $null = mkdir "$($Table.Outputpath)\Archive"
    }
    $FormattedTime = Get-Date -f "dd-MM-yyyy"
    Copy-Item -Path "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -Destination "$($Table.Outputpath)\Archive\$($Table.SiteCode)-$Env:COMPUTERNAME-$($FormattedTime).csv" -Force
    Remove-Item -Path "$($Table.Outputpath)\$($Table.SiteCode)-$Env:COMPUTERNAME.csv" -Force    
}