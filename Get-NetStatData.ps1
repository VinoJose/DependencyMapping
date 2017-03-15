
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
.FUNCTIONALITY
   Importing config file and gives output as hash table.
#>
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1',
                   ConfirmImpact='Medium')]
    [OutputType([HashTable])]
    Param
    (
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $InputObject
    )

    Begin
    {
        $AppSettings = @{}
    }
    Process
    {
     foreach ($Line in $InputObject) 
        {
        $AddNode = $Line.Split("=")
        if(($AddNode[1]).Contains(‘,’)) 
         {
            $Value = ($AddNode[1]).Split(‘,’)
            for ($i = 0; $i -lt $Value.length; $i++) 
            { 
                $Value[$i] = $Value[$i].Trim() 
            }
         }
         else 
         {
            $Value = $AddNode[1].trim(" ")
         }
         $AppSettings[$AddNode[0].trim(" ")] = $Value
        }
    }
    End
    {
        $AppSettings
    }
}

function Find-FreeDiskSpace {
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
                   ConfirmImpact='Medium')]
    [OutputType([Int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
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
        $ExecutionTime = Get-Date -f "dd/MM/yyyy HH:mm:ss"
        Try {
            $data = netstat -ano
        }
        Catch {
            Throw "Error while executing netstat command"
        }
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
                    TimeStamp = $ExecutionTime
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
                    TimeStamp = $ExecutionTime
                }
            }
                        
            Write-Verbose "Output the current line"
            New-Object -TypeName PSObject -Property $properties |Select-Object TimeStamp, LocalIP, RemoteIP, LocalPort, RemotePort, Protocol, State, PID
        }
    }
    End {
        Write-Verbose "Completed fetching the network connection details"
    }
}

function Export-NetstatData {
<#
.Synopsis
   Exports Netstat data to a CSV File.
.DESCRIPTION
   Takes the output from Get-NetStat and exports it as a CSV file after applying the filter given.
.EXAMPLE
   Get-NetStat | Export-NetstatData -filter $Filter
.INPUTS
   Output of Get-NetStat is the input for this Cmdlet
.OUTPUTS
   There is no output for this cmdlet. Creates a CSV file.
.NOTES
   General notes
.FUNCTIONALITY
   Exports Netstat data to a CSV File.
#>
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1',
                   ConfirmImpact='Medium')]
    Param
    (
        #This should be output from Get-Netstat function
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $NetstatData,
        [Parameter(Mandatory=$true, 
                   Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $Filter,
        [Parameter(Mandatory=$true, 
                   Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $OutputPath,
        [Parameter(Mandatory=$true, 
                   Position=3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $SiteCode
    )
    Begin {
        Write-Verbose "Initiating an empty array to store the NetstatData"
        $Netstat = @()
    }
        
    Process {
        #Executing the Get-Netstat function to fetch the data.
        Write-Verbose "Adding the output of Get-NetstatData to the array"    
        $Netstat += $NetstatData
    }

    End {
        $CurrentErrorActionPref = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"

        #Filtering the output.
        Write-Verbose "Filtering the output" 
        $Output = $Netstat | Where-Object {$_.LocalIP -ne "0.0.0.0" -and $_.LocalIP -ne "127.0.0.1" -and $_.LocalIP -match [ipaddress]$_.LocalIP} |
        Where-Object $Filter |Select-Object -Property *, @{Label = "SiteCode"; e= {$SiteCode}}
    
        #Resloving hostnames for the remote ip addresses.
        Write-Verbose "Resloving hostnames for the remote ip addresses"
        foreach ($item in $Output) {
            $RemoteHostName =  $Null
            $RemoteHostName = [System.Net.Dns]::GetHostEntry($item.RemoteIP).HostName
            if ($RemoteHostName) {
                $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $RemoteHostName -ErrorAction Stop
            }
            else {
                $item | Add-Member -NotePropertyName RemoteHostName -NotePropertyValue $Null -ErrorAction Stop
            }
        }
        $ErrorActionPreference = "Stop"
    
        #Exporting the output to the CSV file.
        Write-Verbose "Exporting the output to the CSV file"
        Try {
            if (Test-Path "$($OutputPath)\$($SiteCode)-$Env:COMPUTERNAME.csv") {
                $Output | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath "$($OutputPath)\$($SiteCode)-$Env:COMPUTERNAME.csv" -Append -Encoding ascii
            }
            else {
                $Output | Export-Csv "$($OutputPath)\$($SiteCode)-$Env:COMPUTERNAME.csv" -NoTypeInformation   
            }
        }
        Catch {
            Throw "Error during exporting output as CSV file. Error Message : $_"
        }
        Finally {
            $ErrorActionPreference = $CurrentErrorActionPref
        }
    }
}

function Main {
    #Importing the input data
    Write-Verbose "Importing the input data"
    Try {
        $Data = Get-Content "$ScriptPath\Input.config" -ErrorAction Stop
        $Table = $Data | Import-Config -ErrorAction Stop
    }
    Catch {
        Throw "Error occurred while importing the data from input file. Please check whether input file is present. Error Message : $_"
    }

    #Checking and output path and creating it if not exists
    Write-Verbose "Checking and output path and creating it if not exists"
    if (!(Test-Path $Table.Outputpath)) {
        Try {
            $null= mkdir $Table.Outputpath -Force -ErrorAction Stop
        }
        Catch {
            Throw "Can't create directory specified in the input file. Please check the path given is valid. Error message : $_"
        }
    }

    #Checking the diskspace avaliable in the drive where outputfile is generated.
    Write-Verbose "Checking the diskspace avaliable in the drive where outputfile is generated"
    $FreeSpace = Find-FreeDiskSpace -DriveLetter $(($Table.Outputpath).Split("\")[0])
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
            Get-NetStat | Export-NetstatData -Filter $Filter -OutputPath $Table.Outputpath -SiteCode $Table.SiteCode
            Start-Sleep -Seconds $Table.Interval
        } 
        Until (((Get-date) - $StartTime).TotalDays -ge 7 )
    }

    #'else' block will run if the script is executed using Task Scheduler
    else {
        Get-NetStat | Export-NetstatData -Filter $Filter -OutputPath $Table.Outputpath -SiteCode $Table.SiteCode
    }
}
#endregion

Main
