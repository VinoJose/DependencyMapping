$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
#. "$here\$sut"

Describe "Get-NetStatData" {
function Import-Config {}
function Find-freeDiskSpace {}
function Get-NetStat {}
function Export-NetstatData {}
Mock Import-Config {
    @{
        Interval = 30
        IPsToExclude = "10.0.0.1","192.1.2.3","10.104.166.1","0.0.0.0"
        RemoteHostname = "True"
        SiteCode = "MDC"
        Outputpath = "C:\Temp"
    }
}
Mock Find-freeDiskSpace {}
Mock Get-NetStat {}
Mock Export-NetstatData {}
Mock Get-Content {
"Interval = 30","IPsToExclude = 10.0.0.1,192.1.2.3,10.104.166.1,0.0.0.0","RemoteHostname = True","SiteCode = MDC","Outputpath = C:\Temp"
}
Mock Test-Path
    It "does something useful" {
        Main 
        Assert-MockCalled -CommandName Find-freeDiskSpace -Exactly 0 -Scope It
    }
}
