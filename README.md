# PoShPRTG
A PowerShell module for [PRTG Network Monitor](https://www.paessler.com/prtg).


### Installation
 - Copy `Posh-PRTG.psm1` to your PowerShell modules location (e.g `%UserProfile%\Documents\WindowsPowerShell\Modules\PoShPRTG\PoSh-PRTG.psm1` or `%Windir%\System32\WindowsPowerShell\v1.0\Modules\PoShPRTG\PoSh-PRTG.psm1`)


### Getting Started
`Get-Command *PRTG*` will list all the CmdLets exposed by PoShPRTG.

**List all PRTG Devices:**
`Get-PRTGDevice`

**Get Sensor Details for Sensor #1337:**
`Get-PRTGSensorDetails -SensorID 1337`


### Sessions:
PoShPRTG _"sessions"_ can be used so you don't have to supply credentials with every CmdLet. Most CmdLets take a `-Session` parameter, which can be used as follows:
`$Session = New-PRTGSession -Url $Url -Username prtgadmin -PassHash 1234567890 -Persistent`
`Get-PRTGDevice -Session $Session`

If you use the `-Persistent` flag when creating the session, your credentials are stored in a Global variable, which all subsequent PoShPRTG CmdLets will attempt to use when no `-Session` parameter is specified
`New-PRTGSession -Url $Url -Username prtgadmin -PassHash 1234567890 -Persistent`
_Note: This is obviously not very secure and is provided for convenience. It should be used very carefully/sparingly._


### Executing Raw API Requests:
`Invoke-PRTGAPI -Url "https://monitoring.domain.tld" -Endpoint "table.xml" -Username prtgadmin -PassHash 1234567890 -Parameters @{content="devices"; id = 1337}`
