### New-PRTGSession -Url $Url -Username prtgadmin -PassHash 1234567890 -Persistent
### $Session = New-PRTGSession -Url $Url -Username prtgadmin -PassHash 1234567890 -Persistent
### Invoke-PRTGAPI -Url $Url -Endpoint "table.xml" -Username prtgadmin -PassHash 1234567890 -Parameters @{content="devices"; id = 1337}
### Get-PRTGSensorDetails -SensorID 1337


# This Function has no Parameter Sets and no Mandatory parameters so that we can just "splat" calls to the other functions straight into it, without it complaining.
# Url, Endpoint and at least 1 auth Method (Credentials or UserName/PassHash) are required (but can't be marked Mandatory without breaking everything).
Function Invoke-PRTGAPI
{
<#
  .SYNOPSIS
  Makes a call to the PRTG API and returns the result as XML.
  .DESCRIPTION
  Makes a call to the PRTG API and returns the result as XML.
  .EXAMPLE
  Invoke-PRTGAPI -Url "https://prtg.contoss.com/api/" -Credential $Credential
  .EXAMPLE
  Invoke-PRTGAPI -Url "https://prtg.contoss.com/api/" -Username prgadmin -PassHash 43298432
  .PARAMETER Credentials
  The PSCredentials object used to connect to PRTG. Can be a local PRTG user or an AD synchronised PRTG user.
  .PARAMETER Username
  The Username used to connect to PRTG. Note: Must be a local PRTG user, as AD synchronised users do not have a passhash.
  .PARAMETER PassHash
  The PassHash used to connect to PRTG. Can be found in the User Profile page of a local PRTG user. Note: Must be a local PRTG user, as AD synchronised users do not have a passhash.
  .PARAMETER Url
  The base path to PRTG, e.g prtg.contosso.com or https://prtg.contosso.com:8443"
  .PARAMETER Endpoint
  The name of the 'endpoint' you are using, e.g. 'table.xml' or 'getsensordetails.xml'
  .PARAMETER Parameters
  A HashTable containing keyvalue pairs which are passed in the body of the API request. Usually used to sort or limit results returned.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG instance.')]
    [String]$Url,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The endpoint you want to hit.')]
    [String]$Endpoint,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of API parameter keyvalue pairs.')]
    [HashTable]$Parameters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [String]$Username,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [String]$PassHash
)

    # Unwrap the Session Parameter (if supplied)
    If ($Session) {
        $Url = $Session.Url
        $Credentials = $Session.Credentials
        $Username = $Session.Username
        $PassHash = $Session.PassHash
    }

    # Use the Persistent session (if it exists) and explicit values aren't defined
    If ($Global:PRTGSession) {
        If (!$Url) { $Url = $Global:PRTGSession.Url }
        If (!$Credentials) { $Credentials = $Global:PRTGSession.Credentials }
        If (!$Username) { $Username = $Global:PRTGSession.Username }
        If (!$PassHash) { $PassHash = $Global:PRTGSession.PassHash }
    }
    
    #Add the credentials to a variable to be used as the "body" of the HTTP Request (will become GET params)
    $Body   = @{ }
    If ($Credentials) {
        $Body.username = $Credentials.UserName
        $Body.password = $Credentials.GetNetworkCredential().Password
    }
    ElseIf ($Username -And $PassHash) {
        $Body.username = $Username
        $Body.passhash = $PassHash
    }
    Else {
        Throw "You must supply either Credentials or a Username and PassHash."
    }

    #Verify that the URL and Endpoint have been supplied.
    If (!$Url) {
        Throw "You must specify the base Url of the PRTG instance by providing the -Url parameter."
    }
    ElseIf (!$Endpoint) {
        Throw "You must specify the Endpoint."
    }

    Try {
        $Url = $Url + "/api/" + $Endpoint
        If ($Verbose) { $Result = Invoke-WebRequest -Method Get -Uri $Url -Body ($Body + $Parameters) -UseBasicParsing -ErrorAction Stop -Verbose}
        Else          { $Result = Invoke-WebRequest -Method Get -Uri $Url -Body ($Body + $Parameters) -UseBasicParsing -ErrorAction Stop}
        If ($Result.StatusCode -Eq 200) {

            If ($Verbose) { Write-Warning $Result.Content }

            [xml]$XML = $Result.Content

            Return $XML
        }
    }
    Catch {
        Throw $_
    }
}


Function New-PRTGSession
{
<#
  .SYNOPSIS
  Creates a PRTG Session object, which is a PSObject containing a URL and credentials that can be passed to PRTG cmdlets.
  .DESCRIPTION
  If you set the Persistent switch, it stores the URL and credentials as a global variable which the other PRTG cmdlets try to use if they are not supplied with explicit Url and credentials parameters.
  .EXAMPLE
  Connect-PRTG
  .EXAMPLE
  Connect-PRTG -Url "https://prtg.contoss.com/api/" -Credential $Credential
  .EXAMPLE
  Connect-PRTG -Url "https://prtg.contoss.com/api/" -Username prgadmin -PassHash 43298432
  .PARAMETER Credentials
  The PSCredentials object used to connect to PRTG. Can be a local PRTG user or an AD synchronised PRTG user.
  .PARAMETER Username
  The Username used to connect to PRTG. Note: Must be a local PRTG user, as AD synchronised users do not have a passhash.
  .PARAMETER PassHash
  The PassHash used to connect to PRTG. Can be found in the User Profile page of a local PRTG user. Note: Must be a local PRTG user, as AD synchronised users do not have a passhash.
  .PARAMETER Url
  The base path to PRTG, e.g prtg.contosso.com or https://prtg.contosso.com:8443"
  .PARAMETER Persistent
  If present, will store the "Session" as a global variable which the other PRTG Cmdlets will use if they are not supplied with explicit Url and credentials parameters.
#>
[CmdletBinding(DefaultParameterSetName="Credentials")]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API (including a trailing slash).')]
    [String]$Url,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage="Mark the session as 'persistent' which stores the details in a global variable so that you don't have to supply them with every subsequent cmdlet call.")]
    [Switch]$Persistent
)
    
    #Test the URL and Credentials with a call to table.xml with id=-1 (won't exist)
    Try {
            If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
            Invoke-PRTGAPI -Endpoint "table.xml" -Parameters @{content="test"; filter_objid = "-1"} -Session $Session | Out-Null

        If ($Persistent) {
            $Global:PRTGSession = $Session
        }

        Return $Session
    }
    Catch
    {
        Throw $_
    }
}


Function Remove-PRTGSession
{
<#
  .SYNOPSIS
  Disconnects (destroys) a PRTG instance.
  .DESCRIPTION
  Although this cmdlet is called Remove-PRTGSession, it's not actually really necessary and simply just flushes a variable (or the global variable). It is provided for the sake of completion.
  .EXAMPLE
  Disconnect-PRTG
#>
[CmdletBinding()]
param
(
    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession that you want to flush.')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Persistent", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage="Flush the Persistent session.")]
    [Switch]$Persistent
)

    If ($PSCmdlet.ParameterSetName -Eq "Session") { $Session = $Null }

    If ($PSCmdlet.ParameterSetName -Eq "Persistent") { $Global:PRTGSession = $Null }
}


Function Get-PRTGSession
{
<#
  .SYNOPSIS
  Returns a persistent PRTG Session, if it exists.
  .DESCRIPTION
  Returns a persistent PRTG Session PSOBject, if it exists (or $null if it does not).
  .EXAMPLE
  Get-PRTGSession
#>
  Return $Global:PRTGSession
}








Function Get-PRTGSensorDetails
{
<#
  .SYNOPSIS
  Gets the details of an existing PRTG Sensor.
  .DESCRIPTION
  Uses the PRTG API to get the details of an existing PRTG Sensor as a PSOBject.
  .EXAMPLE
  Get-PRTGSensorDetails -SensorID 1235
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to retrieve the details for.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding(DefaultParameterSetName="Session")]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the PRTG Sensor that you want to edit.')]
    [long]$SensorID,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    If (!$Session) { If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} } }
    $Result = Invoke-PRTGAPI -Endpoint "getsensordetails.xml" -Parameters @{id = $SensorID} -Session $Session
    

    #This is HORRIBLE and causes me much shame, but converting an XML object to a PSObject isnt a oneliner in PowerShell...
    #Also, because of the CDATA the following won't work (easily): http://stackoverflow.com/questions/3242995/convert-xml-to-psobject
    #Doing it manually also allows us to rename/recase the Properties, so there's that...

        $SensorDetails = @{
            Name = $Result.sensordata.name."#cdata-section"
            ID = $SensorID
            SensorType = $Result.sensordata.sensortype."#cdata-section"
            Interval = $Result.sensordata.interval."#cdata-section"
            ProbeName = $Result.sensordata.probename."#cdata-section"
            ParentGroupName = $Result.sensordata.parentgroupname."#cdata-section"
            ParentDeviceID = $Result.sensordata.parentdeviceid."#cdata-section"
            LastValue = $Result.sensordata.lastvalue."#cdata-section"
            LastMessage = $Result.sensordata.lastmessage."#cdata-section"
            Favorite = $Result.sensordata.favorite."#cdata-section"
            StatusText = $Result.sensordata.statustext."#cdata-section"
            StatusID = $Result.sensordata.statusid."#cdata-section"
            LastUp = $Result.sensordata.lastup."#cdata-section"                 #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            LastDown = $Result.sensordata.lastdown."#cdata-section"             #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            LastCheck = $Result.sensordata.lastcheck."#cdata-section"           #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            Uptime = $Result.sensordata.uptime."#cdata-section"                 #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            UptimeTime = $Result.sensordata.uptimetime."#cdata-section"         #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            Downtime = $Result.sensordata.downtime."#cdata-section"             #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            DowntimeTime = $Result.sensordata.downtimetime."#cdata-section"     #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            UpDownTotal = $Result.sensordata.updowntotal."#cdata-section"       #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...
            UpDownSince = $Result.sensordata.updownsince."#cdata-section"       #TODO: This returns a horrible format, ideally we should parse this and Return something nicer...

        }
        Return New-Object PSObject -Property $SensorDetails
}

Function Clone-PRTGSensor
{
<#
  .SYNOPSIS
  Clones an existing PRTG Sensor and returns the ID of the newly created sensor.
  .DESCRIPTION
  Uses the PRTG API to create a new sensor, however the PRTG API only allows you to create a new sensor by cloning an existing sensor.
  .EXAMPLE
  Clone-PRTGSensor -SensorID 1234 -TargetID 5678 -Name My Sensor
  .EXAMPLE
  Get-Content C:\Temp\Input.txt | Foreach-Object {Clone-PRTGSensor -SensorID 5382 -TargetID 2347 -Name (("Queues: " + $_ + " - ActiveMessageCount") -replace "development", "production")}
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to clone.
  .PARAMETER TargetID
  The ID of the Group/Device that the new sensor will be childed to.
  .PARAMETER Name
  The name of the new PRTG Sensor.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of an existing PRTG Sensor that you want to clone.')]
    [long]$SensorID,

    [Parameter(Mandatory=$True, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the Group/Device that the new PRTG Sensor will be childed to.')]
    [long]$TargetID,

    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the new PRTG Sensor.')]
    [String]$Name,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
    $Result = Invoke-PRTGAPI -Endpoint "duplicateobject.htm" -Parameters @{id = $SensorID; targetid=$TargetID} -Session $Session

    If ($Result -Match 'id=(?<ID>\d+)')
    {
        Return New-Object PSObject -Property @{SensorID = $matches.ID}
    }
    Else
    {
        Throw "The PRTG API did not appear to Return the ID of the new sensor. The sensor was probably not successfully created."
    }

}
Function Get-PRTGSensorProperty
{
<#
  .SYNOPSIS
  Gets the property of an existing PRTG Sensor.
  .DESCRIPTION
  Uses the PRTG API to get the property on an existing PRTG Sensor. The Property parameter can be discerned by opening the Settings page of a Sensor and looking at the HTML source of the INPUT fields (and removing the trailing underscore).
  .EXAMPLE
  Get-PRTGSensorProperty -SensorID 1235 -Property "xmlurl"
  .EXAMPLE
  Get-Content C:\input.txt | Foreach-Object {Get-PRTGSensorProperty -SensorID $_ -Property "xmlurl"}
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to retrieve a proeprty for.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the PRTG Sensor that you want to edit.')]
    [long]$SensorID,

    [Parameter(Mandatory=$True, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the property that you want to edit.')]
    [String]$Property,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
    $Result = Invoke-PRTGAPI -Endpoint "getobjectproperty.htm" -Parameters @{id = $SensorID; name = $Property} -Session $Session

    #TODO: ideally need to Return success or failure but blindly assuming it worked will have to do for now...
    #(Returns it's own SensorID so that cmdlet pipelining works)
    $SensorProperty = @{SensorID = $SensorID; Value = $Result.prtg.result}
    Return New-Object PSObject -Property $SensorProperty
}
Function Set-PRTGSensorProperty
{
<#
  .SYNOPSIS
  Sets (edits) the property on an existing PRTG Sensor.
  .DESCRIPTION
  Uses the PRTG API to set the property on an existing PRTG Sensor. The Property parameter can be discerned by opening the Settings page of a Sensor and looking at the HTML source of the INPUT fields (and removing the trailing underscore).
  .EXAMPLE
  Set-PRTGSensorProperty -SensorID 1235 -Property "xmlurl" -Value "http://www.google.com"
  .EXAMPLE
  Get-Content C:\input.txt | Foreach-Object {Set-PRTGSensorProperty -SensorID $_ -Property "xmlurl" -Value "MyValue1"}
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to edit the property of.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the PRTG Sensor that you want to edit.')]
    [long]$SensorID,

    [Parameter(Mandatory=$True, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the property that you want to edit.')]
    [String]$Property,

    [Parameter(Mandatory=$True, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The new value of the property.')]
    [String]$Value,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
    $Result = Invoke-PRTGAPI -Endpoint "setobjectproperty.htm" -Parameters @{id = $SensorID; name = $Property; value = $Value} -Session $Session

    #TODO: ideally need to Return success or failure but blindly assuming it worked will have to do for now...
    #(Returns it's own SensorID so that cmdlet pipelining works)
    Return New-Object PSObject -Property @{SensorID = $SensorID}
}
Function Resume-PRTGSensor
{
<#
  .SYNOPSIS
  Resumes a paused PRTG Sensor.
  .DESCRIPTION
  Uses the PRTG API to resume a paused PRTG Sensor.
  .EXAMPLE
  Resume-PRTGSensor -SensorID 1234
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to resume.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the PRTG Sensor that you want to edit.')]
    [long]$SensorID,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
    $Result = Invoke-PRTGAPI -Endpoint "pause.htm" -Parameters @{id = $SensorID; action = 1} -Session $Session

    #TODO: ideally need to Return success or failure but blindly assuming it worked will have to do for now...
    #(Returns it's own SensorID so that cmdlet pipelining works)
    Return New-Object PSObject -Property @{SensorID = $SensorID}

}

Function Pause-PRTGSensor
{
<#
  .SYNOPSIS
  Pauses a PRTG Sensor.
  .DESCRIPTION
  Uses the PRTG API to pause PRTG Sensor. If you do not specify a length, the sensor will be paused indefinitely.
  .EXAMPLE
  Pause-PRTGSensor -SensorID 1234
  .EXAMPLE
  Pause-PRTGSensor -SensorID 1234 -Duration 60 -Message "Pausing, server powered off for 1 week."
  .PARAMETER SensorID
  The ID of an existing PRTG Sensor that you want to pause.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the PRTG Sensor that you want to edit.')]
    [long]$SensorID,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The Duration (in minutes) to pause the sensor for.')]
    [int]$Duration,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The Pause message.')]
    [int]$Message,

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)

    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }

    $Parameters = @{}
    $Endpoint = ""
    if ($Length)
    {
        $Endpoint = "pauseobjectfor.htm"
        $Parameters = @{
            id=$SensorID
            action=0
            duration=$Duration
            pausemsg=$Message
        }
    }
    else
    {
        $Endpoint = "pause.htm"
        $Parameters = @{
            id=$SensorID
            action=0
        }
    }

    $Result = Invoke-PRTGAPI -Endpoint $Endpoint -Parameters $Parameters -Session $Session
    

    #TODO: ideally need to Return success or failure but blindly assuming it worked will have to do for now...
    #(Returns it's own SensorID so that cmdlet pipelining works)
    Return New-Object PSObject -Property @{SensorID = $SensorID}

}



Function Get-PRTGObject
{
<#
  .SYNOPSIS
  Gets objects (Devices, Sensors, Groups, etc) from PRTG.
  .DESCRIPTION
  Uses the PRTG API to get a list of PRTG Objects as an array.
  .EXAMPLE
  Get-PRTGObject -Type Sensors
  .PARAMETER Name
  The Name of the object you want.
  .PARAMETER ID
  The ID of the object you want.
  .PARAMETER Type
  The Type of objects you want. Valid options are devices, groups or sensors.
  .PARAMETER Columns
  The Columns you want retrieved for each item. A ful list of columns is availible in the PRTG API documentation.
  .PARAMETER Filter
  A HashTable of Keyvalue pairs to filter the data, based on columns. As required by the PRTG API, the word "filter_" is automatically prepended to each key (if not already there). For parameters you don't want prepended with "filter_" (e.g maxresults), use the Parameters parameter.
  .PARAMETER Parameters
  A HashTable of Keyvalue pairs to pass as additional parameters. For filtering, you should use the Filter parameter.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[OutputType([array])]
[CmdletBinding(DefaultParameterSetName=’Session’)]
param
(
    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the Group you want to retrieve.')]
    [String]$Name,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the Group you want to retrieve.')]
    [int]$ID,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A comma separated string of types you are searching for: ["devices", "sensors", "groups"]')]
    [String]$Type = "devices",

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A comma separated list of fields/columns to return')]
    [String]$Columns = "objid,type,name",

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of filter keyvalue pairs.')]
    [HashTable]$Filters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of API parameter keyvalue pairs.')]
    [HashTable]$Parameters = @{},

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)

    If ($Name -And $ID) {
        Write-Warning "Supplying values for both the Name and ID parameters results in a Boolean AND search. Results must match BOTH fields."
    }

    If ($Name) {
        $Parameters.Add("filter_name", $Name)
    }
    If ($ID) {
        $Parameters.Add("filter_objid", $ID)
    }

    # Add any Filters to the Parameters object, prepending any with "filter_" as required.
    $Filters.GetEnumerator() | ForEach-Object {
        If (!$_.Name.StartsWith("filter_")) { $_.Name = ("filter_" + $_.Name) }
        $Parameters.Add($_.Name, $_.Value)
    }

    
    If (!$Session) { $Session = @{Url = $Url;  Credentials = $Credentials; Username = $Username; PassHash = $PassHash} }
    $Result = Invoke-PRTGAPI -Endpoint "table.xml" -Parameters ($Parameters + @{columns = $Columns; content = $Type.ToLower()}) -Session $Session
    
    #$Items += Select-Xml -XML $Result -XPath "//item" | Select-Object -ExpandProperty Node
    [Array]$Items = @($Result.SelectNodes("//item"))

    Return [Array]$Items
}

Function Get-PRTGGroup
{
<#
  .SYNOPSIS
  Gets a list of Groups from PRTG.
  .DESCRIPTION
  Uses the PRTG API to get a list of PRTG Groups as an array.
  .EXAMPLE
  Get-PRTGGroup
  .PARAMETER Name
  The Name of the object you want.
  .PARAMETER ID
  The ID of the object you want.
  .PARAMETER Columns
  The Columns you want retrieved for each item. A ful list of columns is availible in the PRTG API documentation.
  .PARAMETER Filter
  A HashTable of Keyvalue pairs to filter the data, based on columns.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[OutputType([array])]
[CmdletBinding(DefaultParameterSetName=’Session’)]
param
(
    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the Group you want to retrieve.')]
    [String]$Name,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the Group you want to retrieve.')]
    [int]$ID,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='A comma separated list of fields/columns to return')]
    [String]$Columns = "objid,name,host,group,parentid,probe,tags,active,comments",

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of filter keyvalue pairs.')]
    [HashTable]$Filters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of API parameter keyvalue pairs.')]
    [HashTable]$Parameters = @{},

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
    Return @(Get-PRTGObject -Type "groups" @PSBoundParameters)
}


Function Get-PRTGDevice
{
<#
  .SYNOPSIS
  Gets a list of Devices from PRTG.
  .DESCRIPTION
  Uses the PRTG API to get a list of PRTG Devices as an array.
  .EXAMPLE
  Get-PRTGDevice
  .PARAMETER Name
  The Name of the object you want.
  .PARAMETER ID
  The ID of the object you want.
  .PARAMETER Columns
  The Columns you want retrieved for each item. A ful list of columns is availible in the PRTG API documentation.
  .PARAMETER Filter
  A HashTable of Keyvalue pairs to filter the data, based on columns.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[OutputType([array])]
[CmdletBinding(DefaultParameterSetName=’Session’)]
param
(
    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the Device you want to retrieve.')]
    [String]$Name,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the Device you want to retrieve.')]
    [int]$ID,


    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='A comma separated list of fields/columns to return')]
    [String]$Columns = "objid,name,host,group,parentid,probe,tags,active,comments",

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of filter keyvalue pairs.')]
    [HashTable]$Filters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of API parameter keyvalue pairs.')]
    [HashTable]$Parameters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url,


    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash
)

    Return @(Get-PRTGObject -Type "devices" @PSBoundParameters)
}

Function Get-PRTGSensor
{
<#
  .SYNOPSIS
  Gets a list of Sensors from PRTG.
  .DESCRIPTION
  Uses the PRTG API to get a list of PRTG Sensors as an array.
  .EXAMPLE
  Get-PRTGSensor
  .PARAMETER Name
  The Name of the object you want.
  .PARAMETER ID
  The ID of the object you want.
  .PARAMETER Columns
  The Columns you want retrieved for each item. A ful list of columns is availible in the PRTG API documentation.
  .PARAMETER Filter
  A HashTable of Keyvalue pairs to filter the data, based on columns.
  .PARAMETER Credentials
  The Credentials used to connect to PRTG.
  .PARAMETER Url
  The base path to the PRTG API, including a trailing slash. e.g https://prtg.contosso.com/api/"
#>
[OutputType([array])]
[CmdletBinding(DefaultParameterSetName=’Session’)]
param
(
    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The name of the Group you want to retrieve.')]
    [String]$Name,

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The ID of the Group you want to retrieve.')]
    [int]$ID,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='A comma separated list of fields/columns to return')]
    [String]$Columns = "objid,name,sensor,device,host,group,parentid,probe,tags,active,comments, value_, status, message,priority,",

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of filter keyvalue pairs.')]
    [HashTable]$Filters = @{},

    [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A HashTable of API parameter keyvalue pairs.')]
    [HashTable]$Parameters = @{},

    [Parameter(ParameterSetName="Session", Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSObject created with New-PRTGSession')]
    [PSObject]$Session,

    [Parameter(ParameterSetName="Credentials", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='A PSCredentials object. containing the username and password of a PRTG user.')]
    [PSCredential]$Credentials,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The username of a PRTG user.')]
    [String]$Username,

    [Parameter(ParameterSetName="PassHash", Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='The passhash of a PRTG user.')]
    [String]$PassHash,

    [Parameter(Mandatory=$False, ValueFromPipeline=$False, ValueFromPipelineByPropertyName=$True, HelpMessage='The URL of the PRTG API.')]
    [String]$Url
)
   
    Return @(Get-PRTGObject -Type "sensors" @PSBoundParameters)
}
