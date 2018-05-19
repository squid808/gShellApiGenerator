#region General Functions

#Test that the object is (or appears) to be one or all of type $Type
function Test-ObjectType {
    [CmdletBinding()]
    param (

        #One or more types to check the object against. Can include interfaces
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$false)]
        [ValidateScript({$null -ne $_})]
        $Types,

        #The object to check the type(s) of
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateScript({$null -ne $_})]
        $Object,

        #Return true only if all types provided are a match.
        #By default, only one needs to match.
        [Parameter(Mandatory=$false)]
        [switch]
        $MatchAll
    )

    #Make sure Types is iterable
    if ($Types -isnot [System.Collections.IEnumerable]) {
        $Types = @($Types)
    }

    if ($MatchAll) {
        foreach ($Type in $Types) {

            #This may actually error out, eg when checking if something is System.RuntimeType which isn't
            # a valid primary type to convert to but is in the inheritance chain. Thanks reflection!
            if ($Object -isnot $Type -and $Object.PSObject.TypeNames -notcontains $Type) {
                return $false
            }
        }

        return $true
    } else {
        foreach ($Type in $Types) {

            try {
                if ($Object -is $Type) {
                    return $true
                }
            } catch {}

            if ($Object.PSObject.TypeNames -contains $Type) {
                return $true
            }
        }
    }

    #if nothing matches
    return $false
}


#Sanitize comment strings to make sure \n is always \r\n
function Clean-CommentString($String) {
    if ($null -eq $String) {return}

    $string = $string -replace '"',"'"

    return $string
}

function Get-DiscoveryJson ($ApiName) {
    #START HERE - LOAD THE JSON IN FROM A LOCAL FILE
    $RestJson = Get-Content -Path "$env:USERPROFILE\desktop\\Desktop\DiscoveryRestJson\Google.Apis.Discovery.v1.r1.json" | ConvertFrom-Json
}

function Get-ObjProperties ($PSObject) {
    $PSObject.psobject.Properties | % {write-host $_.Name -ForegroundColor Green; Write-Host $PSObject.($_.Name) "`r`n"}
}

function ConvertTo-FirstLower ($String) {
    if ([string]::IsNullOrWhiteSpace($string)){
        return $String
    } else {
        return $String.ToLower()[0] + $String.Substring(1,$String.Length-1)
    }
}

function ConvertTo-FirstUpper ($String) {
    if ([string]::IsNullOrWhiteSpace($string)){
        return $String
    } else {
        return $String.ToUpper()[0] + $String.Substring(1,$String.Length-1)
    }
}

function Has-ObjProperty {
[CmdletBinding()]

    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [object]$PSObject,
    
        [Parameter(Mandatory=$true)]
        [string]$Target
    )
    
    return $PSObject.psobject.Properties.Name -contains $Target
}


#endregion

#region Classes
class ApiScope {
    [string]$Name
    [string]$Description
    [string]$Uri
}

<#
An object container to represent all facets of the Api necessary to generate the
PoSh code on top of it. The Api contains Resources that contain Endpoints, as well
as meta information about the Api itself.

In C# terms, there are Service objects which interface with the Api, and subclasses
that represent Resource containers and  methods for the endpoints.
#>
class Api {
    #The name of the API, eg Gmail
    $Name

    #The lowercase name of the API, eg gmail
    $NameLower

    #The name AND API version, eg Gmail.v1
    $NameAndVersion

    #The lowercase name AND API version, eg gmail.v1
    $NameAndVersionLower

    #The API resources
    $Resources = (New-Object System.Collections.ArrayList)

    #The API resources in a formatted dictionary
    $ResourcesDict = @{}

    #The root namespace, eg Google.Apis.Gmail.v1  (this may not match the APIName)
    $RootNamespace
    
    #The root data namespace, eg Google.Apis.Gmail.v1.Data
    $DataNamespace

    #The API version, eg v1
    $Version

    #The reflection object resulting from the Client Library
    $ReflectedObj

    #The version of the Client Library, eg 1.30.0.1034
    $AssemblyVersion
    
    #The name as coming from the nuget files and rest api, eg Google.Apis.Gmail.v1
    $ApiName

    #The REST object from the Discovery API
    $DiscoveryObj

    #A list of schema objects involved in the API calls - NOT USED?
    #$SchemaObjectsUsed = (New-Object System.Collections.ArrayList)

    #Does this have standard query params
    $HasStandardQueryParams

    #A list of the standard query params
    $StandardQueryparams = (New-Object System.Collections.ArrayList)

    #The base type for the standard query params code, eg ServiceAccountCmdletBase
    $StandardQueryParamsBaseType

    #Can this API use service accounts (eg, is it not an Admin API?)
    $CanUseServiceAccount

    #A list of schema objects involved in the API calls
    $SchemaObjects = (New-Object System.Collections.ArrayList)

    #A dictionary of schema objects by key
    $SchemaObjectsDict = @{}

    #The base type for cmdlets code, eg StandardQueryParametersBase
    $CmdletBaseType

    #The scopes for this API
    $Scopes = (New-Object System.Collections.ArrayList)
}

<#
Create a new Api object
#>
function New-Api {
[CmdletBinding()]
    param(
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        $Assembly,

        #The api's json information from the Google Discovery API
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $RestJson
    )
    $Api = New-Object Api

    $Api.DiscoveryObj = $RestJson
        
    #Full name, eg Google.Apis.Gmail.v1, Version=1.32.2.1139, Culture=neutral, PublicKeyToken=4b01fa6e34db77ab
    $Api.RootNamespace = $Assembly.FullName.Split(",")[0] -replace "\.Admin\.",".admin."
    $Api.DataNamespace = $Api.RootNamespace + ".Data"
    $Api.Version = $Api.RootNamespace.Split(".")[-1]
    $Api.ReflectedObj = $Assembly
    if ($Assembly.Fullname -match "(?<=Version=)([.0-9])+") {
        $Api.AssemblyVersion = $Matches[0]
    }
    $Api.Name = $Api.RootNamespace.Split(".")[-2]
    $Api.NameLower = ConvertTo-FirstLower $Api.Name
    $Api.NameAndVersion = $Api.RootNamespace -replace "^Google.Apis.","" -replace "admin\.",""
    $Api.NameAndVersionLower = ConvertTo-FirstLower $Api.NameAndVersion
    $Api.HasStandardQueryParams = Has-ObjProperty $RestJson "parameters"

    $StdQueryParams = Get-ApiStandardQueryParams -Assembly $Assembly -RestJson $RestJson -Api $Api
    $Api.StandardQueryparams.AddRange($StdQueryParams)

    $Resources = Get-Resources $Assembly
    $Api.Resources.AddRange($Resources)
    $Resources | % {$Api.ResourcesDict[$_.name] = $_}

    $Scopes = Get-ApiScopes -Assembly $Assembly -RestJson $RestJson
    $Api.Scopes.AddRange($Scopes)

    $BaseTypes = Get-ApiGShellBaseTypes `
        -RootNamespace $Api.RootNamespace `
        -HasStandardQueryParams $Api.HasStandardQueryParams

    $Api.CanUseServiceAccount = $BaseTypes.CanUseServiceAccount
    $Api.StandardQueryParamsBaseType = $BaseTypes.StandardQueryParamsBaseType
    $Api.CmdletBaseType = $BaseTypes.CmdletBaseType
    
    return $Api
}

<#
Retrieves the list of standard query parameters for the provided Api. SQPs are parameters
that are a given for all of the endpoints for this api, for example: detailing what fields
to return in a result or an email address that should be used for a service account to 
impersonate. These may or may not exist and differ between Apis.
 #>
 function Get-ApiStandardQueryParams {
    [CmdletBinding()]
    param (
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        $Assembly,

        #The api's json information from the Google Discovery API
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $RestJson,

        #The Api object to be referenced
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-ObjectType "Api" $_})]
        $Api
    )

    $Results = New-Object System.Collections.ArrayList

    #TODO - throw error if more than one result?
    #Note that this won't work unless all other dependent assemblies are also loaded, see: Import-GShellAssemblies
    #Alt is described in most apis as 'Data format for the response.' which is already handled by the underlying .Net API Client
    foreach ($Param in ($Assembly.ExportedTypes | where {$_.Name -like "*BaseServiceRequest?1" `
                -and $_.BaseType.Name -eq "ClientServiceRequest``1"} | select -ExpandProperty DeclaredProperties) `
                | where Name -notlike "alt")
    {
        $P = New-Object ApiMethodProperty
        $P.Api = $Api
        $P.ReflectedObj = $Param
        $P.Name = $Param.Name
        $P.NameLower = ConvertTo-FirstLower $Param.Name
        $P.Type = Get-ApiPropertyType -Property $P
        $DiscoveryName = $Param.CustomAttributes | where AttributeType -like "*RequestParameterAttribute" | `
            select -ExpandProperty ConstructorArguments | select -First 1 -ExpandProperty Value
        $P.Description = $RestJson.parameters.($DiscoveryName).Description
        $Results.Add($P) | Out-Null
    }

    return ,$Results
 }

<#
Determine the base types for the gShell C# code - where will it inherit from?
This helps ensure the proper methods are available to the right APIs, for instance -
Should this Api have service account support for admins? This assumes that any APIs
that are not discovery or admin support a service account, until proven otherwise.
#>
function Get-ApiGShellBaseTypes {
    [CmdletBinding()]
    param (
        # The api's root namespace
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -like "Google.Apis.*"})]
        [string]
        $RootNamespace,

        # Does the API have standard query parameters
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [bool]
        $HasStandardQueryParams
    )

    if ($RootNamespace -like "google.apis.discovery*") {
        $StandardQueryParamsBaseType = "OAuth2CmdletBase"
        $CmdletBaseType = "StandardQueryParametersBase"
        $CanUseServiceAccount = $false
    } elseif ($RootNamespace -like "google.apis.admin*") {
        $CanUseServiceAccount = $false

        if ($HasStandardQueryParams -eq $true) {
            $StandardQueryParamsBaseType = "AuthenticatedCmdletBase"
            $CmdletBaseType = "StandardQueryParametersBase"
        } else {
            $CmdletBaseType = "AuthenticatedCmdletBase"
        }
    } else {
        $CanUseServiceAccount = $true
        
        if ($HasStandardQueryParams -eq $true) {
            $CmdletBaseType = "StandardQueryParametersBase"
            $StandardQueryParamsBaseType = "ServiceAccountCmdletBase"
        } else {
            $CmdletBaseType = "ServiceAccountCmdletBase"
        }
    }

    $Results = [PSCustomObject]@{
        CmdletBaseType = $CmdletBaseType
        StandardQueryParamsBaseType = $StandardQueryParamsBaseType
        CanUseServiceAccount = $CanUseServiceAccount
    }

    return $Results
}

<#
Pull out the scopes from the Api and return objects in a collection.  Scopes are URIs
that tell the Api (and Api Clients) what permissions have been authorized for the service
running the code.
#>
function Get-ApiScopes {
    [CmdletBinding()]
    param (
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        [ValidateNotNull()]
        $Assembly,

        #The api's json information from the Google Discovery API
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $RestJson
    )

    $Results = New-Object System.Collections.ArrayList

    $Scopes = $Assembly.ExportedTypes | where Name -eq Scope

    #set the scopes
    if  ($Scopes -ne $null) {
        foreach ($D in ($Scopes | select -ExpandProperty DeclaredFields)){
            $S = new-object ApiScope
            $S.Name = $D.Name
            $S.Uri = Get-DeclaredFieldValue $D
            $S.Description = $RestJson.auth.oauth2.scopes.($S.Uri).description
            $Results.Add($S) | Out-Null
        }
    } else {
        #Todo - will this break the discovery API?
        throw "No scopes found in the assembly, cannot proceed."
    }

    return ,$Results
}

<#
Wraps [System.Reflection.RtFieldInfo]::GetValue for mocking abilities since we can't
otherwise mock this class's .net method
#>
function Get-DeclaredFieldValue {
    [CmdletBinding()]
    param (
        # A RuntimeFieldInfo object
        [ValidateScript({Test-ObjectType "System.Reflection.FieldInfo" $_})]
        [ValidateNotNullOrEmpty()]
        $DeclaredField
    )

    return $DeclaredField.GetValue($DeclaredField)
}

#Return *all* resources exported from this assembly
function Get-Resources {
    [CmdletBinding()]
    param (
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        $Assembly,

        #The api object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "Api" $_})]
        $Api
    )

    $Service = $Assembly.ExportedTypes | where {$_.BaseType.FullName -eq "Google.Apis.Services.BaseClientService"}
    $Resources = $Service.DeclaredProperties | where {$_.GetMethod.ReturnType -like "Google.Apis*"}

    $Results = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $R = New-ApiResource -Resource $Resource -Api $Api -RestJson $Api.DiscoveryObj

        $Results.Add($R) | Out-Null
    }

    return ,$Results
}

<#
A class representing an Api Resource. This is a logical container
for similar Api endpoints and other containers, which can be seen 
on an Api's "API REFERENCE" webpage. For example, in the Gmail Api
Users resource contains Users.Drafts and Users.Labels,  the latter
of which contains Get, List, Update, Delete, etc.
#>
class ApiResource {
    #A reference to the main Api object
    $Api

    #Reference to the Google Discovery Rest object
    $DiscoveryObj

    #Reference to the reflected assembly object
    $ReflectedObj

    #The resource name, eg Gmail's UserResource. 
    $Name

    #The resource name in first-lower, eg userResource
    $NameLower

    #The fully qualified C# name of the resource, eg Google.Apis.Gmail.v1.UsersResource
    $FullName

    #The resource's C# namespace, eg Google.Apis.Gmail.v1
    $Namespace

    #The parent resource to this one, if one exists. Null if not.
    $ParentResource

    #The child resource(s) to this one, if any. Empty list if not.
    $ChildResources = (New-Object System.Collections.ArrayList)

    #A dictionary collection for child resources, if any. Keyed by Resource name.
    $ChildResourcesDict = @{}

    #A collection of methods for this resource
    $Methods = (New-Object System.Collections.ArrayList)

    #A collection of methods for this resource keyed by method name
    $MethodsDict = @{}
}

<#
Given a reflected resource object, create and return a wrapped ApiResource 
object.
#>
function New-ApiResource {
    [CmdletBinding()]
    param (        
        #The reflected resource object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.PropertyInfo" $_})]
        $Resource,

        #The api object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "Api" $_})]
        $Api,

        #The api's json information from the Google Discovery API
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $RestJson,
        
        [ValidateScript({Test-ObjectType "ApiResource" $_})]
        $ParentResource=$null
    )

    $t = $Resource.PropertyType

    $R = New-Object ApiResource

    $R.Api = $Api
    $R.ReflectedObj = $t
    $R.Name = ConvertTo-FirstUpper ($t.Name -replace 'Resource$',"")
    $R.NameLower = ConvertTo-FirstLower $R.Name
    $R.FullName = $t.FullName
    $R.Namespace = $t.Namespace

    if ($ParentResource -ne $null) {
        $R.ParentResource = $ParentResource
    }
    $R.DiscoveryObj = $RestJson.resources.($R.Name)
    
    #Handle Children Resources
    if ($null -ne $t.DeclaredProperties -and $t.DeclaredProperties.Count -gt 0) {
        foreach ($CR in $t.DeclaredProperties) {
            $ChildR = New-ApiResource -Resource $CR -Api $Api -RestJson $R.DiscoveryObj -ParentResource $R
            $R.ChildResources.Add($ChildR) | Out-Null
            $R.ChildResourcesDict[$ChildR.Name] = $ChildR
        }
    }

    $Methods = Get-ApiResourceMethods $R $T
    
    $R.Methods.AddRange($Methods)
    $Methods | ForEach-Object {$R.MethodsDict[$_.Name] = $_}

    return $R
}

<#
Pulls out methods from the resource that represent the Api endpoints.
Additionally links up upload methods to their generic methods.
#>
function Get-ApiResourceMethods {
    [CmdletBinding()]
    param(
        #The ApiResource object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiResource" $_})]
        $Resource,

        #The reflected resource object's PropertyType 
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.TypeInfo" $_})]
        $ResourceType
    )

    $AllMethods = $ResourceType.DeclaredMethods | Where-Object {$_.IsVirtual -and -not $_.IsFinal}

    #Sort out standard methods first - this will not gather upload methods yet
    $Methods = $AllMethods | Where-Object {$_.ReturnType.ImplementedInterfaces.Name -contains "IClientServiceRequest"}
    
    #Methods where virtual and return type implements IClientServiceRequest
    $Results = New-Object System.Collections.ArrayList

    foreach ($Method in $Methods) {
        $M = New-ApiMethod $resource $method

        $Results.Add($M) | Out-Null
    }
    
    #now process methods that have a file upload option
    foreach ($Method in ($AllMethods | Where-Object {$_.ReturnType.BaseType -like "Google.Apis.Upload.ResumableUpload*"})) {
        $Parameters = Get-MethodInfoParameters $Method
        if ($Parameters.Count -gt 0 -and $Parameters.ParameterType.FullName -contains "System.IO.Stream") {
        
            $M = New-ApiMethod $resource $method -UseReturnTypeGenericInt 1
            $M.SupportsMediaUpload = $true
            foreach ($P in $M.Parameters) {
                if ($P.type.type -eq "System.IO.Stream" -or `
                    ($P.Name -eq "ContentType" -and $P.Type.Type -eq "string")){
                    $P.ShouldIncludeInTemplates = $false
                    $P.Required = $false
                }
            }
            
            #we don't add these to the list of methods directly b/c we want them
            #to only be processed after their 'master' method.
            #find the preexisting method we've aggregated that has the same name and indicate that it supports media upload
            $BuiltMethod = $Results | Where-Object Name -eq $Method.Name
            $BuiltMethod.UploadMethod = $M
        }
    }

    return ,$Results
}

<#
Wraps [System.Reflection.MethodInfo]::GetParameters for mocking abilities since we can't
otherwise mock this class's .net method
#>
function Get-MethodInfoParameters {
    [CmdletBinding()]
    param (
        #A reflected Method Info Object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.MethodInfo" $_})]
        $Method
    )

    #System.Reflection.ParameterInfo[]
    return ,$Method.GetParameters()
}

<#
An object to represent an Api Endpoint (Method).

The api method call is broken up in to two parts in the underlying code:
    The Virtual Method
        - a method that returns an object of type of the request class
        - is of a virtual type
        - parameters are almost always the required parameters for the API call
    The Request Class
        - a class that contains properties for each API parameter, including those from the virtual method
        - properties include custom attributes that indicate the parameter name and parameter type (path, query, custom)
#>
class ApiMethod {
    #Reference to the main Api object
    $Api

    #Reference to the container resource
    $Resource

    #Reference to the container resource
    $ParentResource

    #The name of the method derived from the Virtual method
    $Name

    #The name of the method derived from the Virtual method in first-lower case
    #$NameLower

    #The type ultimately returned by the api call itself, not the method that returns a request type
    $ReturnType

    #Are the results paged
    #[bool]$HasPagedResults

    #All parameters related to this API call - pulled out of both the virtual method and the request class
    $Parameters = (New-Object system.collections.arraylist)

    #All parameters related to this API call in a dictionary
    $ParametersDict = @{}

    #Parameters related to just the virtual method
    $VirtualParameters = (New-Object system.collections.arraylist)

    #Parameters from the request class only
    $RequestParameters = (New-Object system.collections.arraylist)

    #If the virtual method takes in an object as a parameter named 'body' - used to determine if there is a subobject required
    [bool]$HasBodyParameter

    #The body parameter from the virtual method, if any
    $BodyParameter

    #The description of the method
    [string]$Description

    #This method's reflected representation
    $ReflectedObj

    #This method's discovery API representation
    $DiscoveryObj

    #This method supports media download, evidenced by presence of MediaDownloader property on method reflected object return type properties and json
    [bool]$SupportsMediaDownload

    #This method supports media upload, evidenced by the return type's base type of ResumableUpload, and by having a 
    #parameter deriving from System.IO.Stream
    [bool]$SupportsMediaUpload

    #A link to a version of this method that supports Media Upload
    $UploadMethod

    #[string]$MethodVerb

    #[string]$MethodNoun

    #Constructor - use this to add getters for some properties via scriptmethods
    ApiMethod  () {

        #The name of the method derived from the Virtual method in first-lower case
        $this | Add-Member -Name "NameLower" -MemberType ScriptProperty -Value {
            return ConvertTo-FirstLower $this.Name
        }

        $this | Add-Member -Name "MethodVerb" -MemberType ScriptProperty -Value {
            return Get-MCVerb $this.Name
        }

        $this | Add-Member -Name "MethodNoun" -MemberType ScriptProperty -Value {
            return Get-ApiMethodNoun -ApiMethod $this.Api.Version -ApiName $this.Api.Name -ApiVersion $this.Api.Version
        }

        $this | Add-Member -Name "HasPagedResults" -MemberType ScriptProperty -Value {
            return Test-ApiMethodHasPagedResults -ApiMethod $this -Method $this.ReflectedObj
        }

    }
}

<#
Returns a cmdlet noun as determined by the Api
#>
function Get-ApiMethodNoun {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-ObjectType "ApiMethod" $_})]
    $ApiMethod,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ApiName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ApiVersion
)

    $Noun = "G" + $ApiName + (ConvertTo-FirstUpper $ApiVersion) + `
        (Get-ParentResourceChain -MethodOrResource $ApiMethod -JoinChar "")

    return $Noun

}

function New-ApiMethod {
    [CmdletBinding()]
    param (
        #The ApiResource object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiResource" $_})]
        $Resource,
        
        #The Reflected Method object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.MethodInfo" $_})]
        $Method,
        
        [Parameter(Mandatory=$false)]
        $UseReturnTypeGenericInt=0
    )

    $M = New-Object ApiMethod
    $M.Resource = $Resource
    $M.Api = $Resource.Api
    $M.ParentResource = $Resource
    $M.ReflectedObj = $Method
    $M.DiscoveryObj = $Resource.DiscoveryObj.methods.($Method.name)

    $M.Name = ConvertTo-FirstUpper $Method.Name
    $M.Description = Clean-CommentString $M.DiscoveryObj.description
    $M.ReturnType =  New-ApiMethodProperty $M (Get-ApiMethodReturnType $Method -UseReturnTypeGenericInt $UseReturnTypeGenericInt)

    $M.ReturnType.Type = Get-ApiMethodReturnTypeType -MethodReturnTypeName $M.ReturnType.Name
    
    $ParameterNames = New-Object "System.Collections.Generic.HashSet[string]"

    #get the properties of the virtual method. This may include a body
    foreach ($P in (Get-MethodInfoParameters -Method $Method | Where-Object {$Api.StandardQueryparams.Name -notcontains $_.Name})) {
        $ParameterNames.Add($P.Name.ToLower()) | Out-Null
        $Param = New-ApiMethodProperty $M $P -ForceRequired $true

        $M.Parameters.Add($Param) | Out-Null
        $M.VirtualParameters.Add($Param) | Out-Null
    }
    
    #get the properties of the request class - those missing set methods are generally properties not associated with
    # the api -MethodName, HttpMethod and RestPath. Properties with setters are likely to be those we want to update
    # and send along with the API request
    foreach ($P in ($M.ReflectedObj.ReturnType.DeclaredProperties | Where-Object {`
        $_.SetMethod -ne $null `
        -and $_.Name.ToLower() -ne "pagetoken" `
        -and $Api.StandardQueryparams.Name -notcontains $_.Name}))
    {
    
        if (-not $ParameterNames.Contains($P.Name.ToLower())) {
            $Param = New-ApiMethodProperty $M $P
        
            $M.Parameters.Add($Param) | Out-Null
            $M.RequestParameters.Add($Param) | Out-Null
        }
    }

    $M.Parameters | ForEach-Object {$M.ParametersDict[$_.Name] = $_ }

    #$M.HasPagedResults = $Method.ReturnType.DeclaredProperties.name -contains "PageToken" -and `
    #                        $M.ReturnType.ReflectedObject.DeclaredProperties.name -contains "NextPageToken"

    return $M
}

function Test-ApiMethodHasPagedResults {
    [CmdletBinding()]
    param (
        #The Api Method object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiMethod" $_})]
        $ApiMethod,

        #The Reflected Method object
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.MethodInfo" $_})]
        $Method
    )

    $HasPagedResults = $Method.ReturnType.DeclaredProperties.name -contains "PageToken" -and `
        $ApiMethod.ReturnType.ReflectedObject.DeclaredProperties.name -contains "NextPageToken"

    return $HasPagedResults
}

<#
Determines the type of the return type, under unusual circumstances
#>
function Get-ApiMethodReturnTypeType {
    [CmdletBinding()]
    param  (
        #The ApiMethod object
        [Parameter(Mandatory=$true)]
        [string]
        $MethodReturnTypeName
    )

    <#
    if (Has-ObjProperty $M.DiscoveryObj "response") {
        #$M.ReturnType.Type = Get-ApiPropertyTypeShortName $M.ReturnType.ReflectedObj.FullName $M.Api
    } else
    #>
    if ($MethodReturnTypeName -like "String") {
        #Found in media downloads
        $Result = New-BasicTypeStruct string
    } else {
        $Result = New-BasicTypeStruct void
    }

    return $Result
}

class ApiMethodProperty {
    #Reference to the main Api object
    $Api

    #Reference to the containing method
    $Method
    
    #The property's name
    $Name

    #The property's name in first-lower case
    $NameLower

    #The property's reflected type, for general use in the .cs templates
    $Type

    #The property's fully qualified type, eg string 
    $FullyQualifiedType

    #A type sanitized for the xml help documents, eg changing List<string> to string[]
    $HelpDocShortType

    #A long type sanitized for the xml help documents, eg changing 
    $HelpDocLongType

    #Is this property mandatory for the API call
    [bool]$Required

    #The description for this property
    $Description

    #This property's reflected representation
    $ReflectedObj

    #This property's discovery API representation
    $DiscoveryObj

    #Is this property of a Schema Object type
    [bool]$IsSchemaObject

    #If applicable, the schema ApiClass representing this object
    $SchemaObject

    [bool]$ShouldIncludeInTemplates = $true

    [bool]$CustomProperty = $false
}

#used to pass around types until it can be put in to the MethodProperty
class ApiPropertyTypeStruct {
    #The property's reflected type, for general use in the .cs templates
    $Type

    #The property's fully qualified type, eg System.String 
    $FullyQualifiedType

    #A type sanitized for the xml help documents, eg changing List<string> to string[]
    $HelpDocShortType

    #A long type sanitized for the xml help documents, eg changing 
    $HelpDocLongType

    $InnerTypes = (New-Object System.Collections.ArrayList)

    ApiPropertyTypeStruct () {}

    ApiPropertyTypeStruct ($Type, $FullType, $HelpShort, $HelpLong) {
        $this.Type = $Type
        $this.FullyQualifiedType = $FullType
        $this.HelpDocShortType = $HelpShort
        $This.HelpDocLongType = $HelpLong
    }
}

<#
Returns a shortened name for a type, as might be used in code.
Eg, System.String -> string
If the type comes from some other namespace, it will attempt to 
reconcile shortening the type by removing the root namespace
#>
function Get-ApiPropertyTypeShortName {
[CmdletBinding()]
    
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ApiRootNameSpace
    )

    switch ($Name) {
        "System.String" {return "string"}
        "String" {return "string"}
        "System.Int32" {return "int"}
        "int32" {return "int"}
        "System.Boolean" {return "bool"}
        "boolean" {return "bool"}
        "System.Int64" {return "long"}        
        "int64" {return "long"}
    }

    $Replaced = $Name -replace ($ApiRootNamespace + ".")

    $Replaced = $Replaced -replace "[+]","."

    return $Replaced
}

<#
Provided a short type name, eg String, create a new ApiPropertyTypeStruct result object for that type
#>
function New-BasicTypeStruct{
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("string","bool","int32","int64","uint64","void")]
        $Type
    )

    switch ($Type) {
        "string" {
            return [ApiPropertyTypeStruct]::New("string","System.String","string","System.String")
        }

        "bool" {
            return [ApiPropertyTypeStruct]::New("bool","System.Boolean","bool","System.Boolean")
        }

        "int32" {
            return [ApiPropertyTypeStruct]::New("int","System.Int32","int","System.Int32")
        }

        "int64" {
            return [ApiPropertyTypeStruct]::New("long","System.Int64","long","System.Int64")
        }

        "uint64" {
            return [ApiPropertyTypeStruct]::New("ulong","System.UInt64","ulong","System.UInt64")
        }

        "void" {
            return [ApiPropertyTypeStruct]::New("void","void","void","void")
        }
    }
}

<#
Provided a ref type and root name space returns an ApiPropertyTypeStruct object.
#>
function Get-ApiPropertyTypeBasic {
[CmdletBinding()]
    param
    (
        #TODO - figure out what types this requires and work in to unit tests?
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $RefType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ApiRootNameSpace
    )

    #TODO - provide overload to provide just a string and create it from there for basic types

    if ($RefType.FullName -eq "System.String" -or $RefType.FullName -eq "String") {
        return (New-BasicTypeStruct string)
    }

    if ($RefType.FullName -eq "System.Boolean" -or $RefType.FullName -eq "boolean") {
        return (New-BasicTypeStruct bool)
    }

    if ($RefType.FullName -eq "System.Int32" -or $RefType.FullName -eq "Int32") {
        return (New-BasicTypeStruct int32)
    }

    if ($RefType.FullName -eq "System.Int64" -or $RefType.FullName -eq "Int64") {
        return (New-BasicTypeStruct int64)
    }

    if ($RefType.FullName -eq "System.UInt64" -or $RefType.FullName -eq "UInt64") {
        return (New-BasicTypeStruct uint64)
    }

    #otherwise...

    $TypeStruct = New-Object ApiPropertyTypeStruct
    $TypeStruct.Type = $RefType.FullName -replace ($ApiRootNamespace + ".") -replace "[+]","."
    $TypeStruct.FullyQualifiedType = $RefType.FullName -replace "[+]","."
    $TypeStruct.HelpDocShortType = $TypeStruct.Type.Split(".")[-1]
    $TypeStruct.HelpDocLongType = $TypeStruct.FullyQualifiedType

    return $TypeStruct
}

<#
Returns a type struct for the given property or runtime type
#>
function Get-ApiPropertyType {
[CmdletBinding()]
    param (
        [Parameter(ParameterSetName="property", Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiMethodProperty" $_})]
        $Property,

        #The type for this actually shows up as System.RuntimeType but who's counting
        [Parameter(ParameterSetName="runtimetype", Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Type","System.RuntimeType" $_})]
        $RuntimeType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ApiRootNameSpace
    )

    if ($PSCmdlet.ParameterSetName -eq "property") {
        #Pull out the runtime type
        #TODO - why aren't we doing this before the method is called?
        if ("ParameterType" -in $Property.ReflectedObj.PsObject.Properties.Name) {
            #if of type RuntimeParameterInfo
            $RefType = $Property.ReflectedObj.ParameterType
        } elseif ("PropertyType" -in $Property.ReflectedObj.PsObject.Properties.Name) {
            #Might also be RuntimePropertyInfo
            $RefType = $Property.ReflectedObj.PropertyType
        } else {
            throw "No Sub RefType found on Property"
        }
    } else {
        $RefType = $RuntimeType
    }

    #Make sure we're not making a property that is declared as a subclass or object (struct, enum) within a generic class without providing the
    #generic type for said parent class.
    #also in cases where reftype's name / fullname are empty, return it right here and now
    if (($Null -ne $RefType.UnderlyingSystemType `
            -and $RefType.UnderlyingSystemType.FullName.Contains("+") `
            -and $null -ne $RefType.DeclaringType `
            -and $RefType.DeclaringType.IsGenericType) `
        -or ([string]::IsNullOrWhiteSpace($RefType.Name) `
            -and [string]::IsNullOrWhiteSpace($RefType.FullName))) {
            return $null
    }

    #is this a generic type? nullable, list, etc
    if (-not [string]::IsNullOrWhiteSpace($RefType.Name) -and $RefType.Name.Contains("``")) {
        
        $TypeStruct = New-Object ApiPropertyTypeStruct

        $InnerTypeStruct = New-Object ApiPropertyTypeStruct

        foreach ($I in $RefType.GenericTypeArguments) {
            if (Test-ObjectType "System.RuntimeType" $I) {
                $InnerTypeStruct = Get-ApiPropertyType -RuntimeType $I -ApiRootNameSpace $ApiRootNameSpace
            } else {
                $InnerTypeStruct = Get-ApiPropertyTypeBasic $I $Api
            }

            if ($InnerTypeStruct -ne $null) {
                $TypeStruct.InnerTypes.Add($InnerTypeStruct) | Out-Null
            }
        }

        #don't return any generics that don't have anything inside
        if ($TypeStruct.InnerTypes.Count -eq 0) { return $null }
        
        if ($TypeStruct.InnerTypes.Count -eq 1) {
            if ($RefType.Name -eq "Repeatable``1") {
                $TypeStruct.Type = "Google.Apis.Util.Repeatable<{0}>" -f $TypeStruct.InnerTypes[0].Type
                $TypeStruct.FullyQualifiedType = "Google.Apis.Util.Repeatable<{0}>" -f $TypeStruct.InnerTypes[0].FullyQualifiedType
                $TypeStruct.HelpDocShortType = "{0}[]" -f $TypeStruct.InnerTypes[0].HelpDocShortType
                $TypeStruct.HelpDocLongType = "{0}[]" -f $TypeStruct.InnerTypes[0].FullyQualifiedType

            } elseif ($RefType.Name -eq "Nullable``1") {
                $TypeStruct.Type = $TypeStruct.InnerTypes[0].Type + "?"
                $TypeStruct.FullyQualifiedType = "System.Nullable<{0}>" -f $TypeStruct.InnerTypes[0].FullyQualifiedType 
                $TypeStruct.HelpDocShortType = $TypeStruct.InnerTypes[0].HelpDocShortType
                $TypeStruct.HelpDocLongType = $TypeStruct.InnerTypes[0].FullyQualifiedType

            } else {
                $TypeStruct.Type = "{0}<{1}>" -f ($RefType.Name.Split("``")[0] -replace "[+]","."), $TypeStruct.InnerTypes[0].Type
                $TypeStruct.FullyQualifiedType = $TypeStruct.Type
                $TypeStruct.HelpDocShortType = $TypeStruct.Type
                $TypeStruct.HelpDocLongType = $TypeStruct.Type
            }
        } else {
            $TypeStruct.Type = "{0}<{1}>" -f ($RefType.Name.Split("``")[0] -replace "[+]","."), ($TypeStruct.InnerTypes.Type -join ", ")
            $TypeStruct.FullyQualifiedType = "{0}<{1}>" -f ($RefType.FullName.Split("``")[0] -replace "[+]","."), ($TypeStruct.InnerTypes.FullyQualifiedType -join ", ")
            $TypeStruct.HelpDocShortType = $TypeStruct.Type
            $TypeStruct.HelpDocLongType = $TypeStruct.FullyQualifiedType
        }

    } else  {
        if (-not [string]::IsNullOrWhiteSpace($RefType.FullName)) {
            
            $TypeStruct = Get-ApiPropertyTypeBasic -RefType $RefType -ApiRootNameSpace $ApiRootNameSpace
        } else {
            #TODO: when does this happen?
            #$TypeStruct.Type = (Get-ApiPropertyTypeBasic -RefType $RefType -ApiRootNameSpace $ApiRootNameSpace)
            throw "ReflectionTest: RefType FullName is null, please revise"
        }
    }

    return $TypeStruct
}

<#
Creates a new object of type ApiMethodProperty given a method and its property
#>
function New-ApiMethodProperty {
[CmdletBinding()]

    Param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiMethod" $_})]
        $Method,
        
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Type","System.RuntimeType" $_})]
        $Property,

        [Parameter(Mandatory=$false)]
        [bool]
        $ForceRequired = $false
    )
    $P = New-Object ApiMethodProperty
    $P.Method = $Method
    $P.Api = $Method.Api
    $P.Name = ConvertTo-FirstUpper $Property.Name
    $P.NameLower = ConvertTo-FirstLower $Property.Name
    $P.ReflectedObj = $Property
    $P.DiscoveryObj = $Method.DiscoveryObj.parameters.($Property.Name)
    if (Test-ObjectType "System.RuntimeType" $P.ReflectedObj) {
        $P.Type = Get-ApiPropertyType -RuntimeType $P.ReflectedObj -ApiRootNameSpace $P.Api.RootNamespace
    } else {
        $P.Type = Get-ApiPropertyType -Property $P -ApiRootNameSpace $P.Api.RootNamespace
    }

    if ($P.Type.FullyQualifiedType -like "*Download.IMediaDownloader"){
        $P.Method.SupportsMediaDownload = $true
        $P.ShouldIncludeInTemplates = $false
    } elseif ($P.Type -eq $Null) {
        $P.ShouldIncludeInTemplates = $false
    }
    
    $P.Description = Clean-CommentString $P.DiscoveryObj.Description

    if ([string]::IsNullOrWhiteSpace($P.Description)){
        $P.Description = "Description for object of type {0} is unavailable." -f $P.Type.HelpDocLongType
    }

    #TODO - is force required really needed?
    $DiscoveryRequiredOutVar = ConvertTo-Bool $P.DiscoveryObj.required
    $P.Required = $ForceRequired -or $DiscoveryRequiredOutVar
    
    #If this is one of the schema objects
    if ($Property.ParameterType.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
        
        $P.IsSchemaObject = $true
        $P.SchemaObject = New-ApiClass -ReflectedObj $P.ReflectedObj.ParameterType -Api $Method.Api

        if ($P.Name -eq "Body") {
            $P.Description = "An object of type " + $P.ReflectedObj.ParameterType
            $Method.HasBodyParameter = $true
            $Method.BodyParameter = $P
        } 
    }

    return $P
}

class ApiClass {
    #Reference to the main Api object
    $Api

    $Name
    $NameLower
    $Type
    #$TypeData
    $Properties = (New-Object System.Collections.ArrayList)
    $Description
    #This class's reflected representation
    $ReflectedObj

    #This class's discovery API representation
    $DiscoveryObj
}

#The complex class representation for the object behind a property, documented as a 'schema object' in Google's json
function New-ApiClass {
[CmdletBinding()]

    Param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Type","System.RuntimeType" $_})]
        $ReflectedObj,

        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "Api" $_})]
        $Api
    )

    $TypeStruct = Get-ApiPropertyType -RuntimeType $ReflectedObj -Api $Api

    if ($Api.SchemaObjectsDict.ContainsKey($TypeStruct.Type)) {
        return $Api.SchemaObjectsDict[$TypeStruct.Type]
    } else {

        $C = New-Object ApiClass

        $C.Api = $Api

        $C.ReflectedObj = $ReflectedObj
        $C.Name = $ReflectedObj.Name
        $C.DiscoveryObj = $C.Api.DiscoveryObj.schemas.($C.Name)
        $C.Type = $TypeStruct
        $C.Description = Clean-CommentString $C.DiscoveryObj.description
        $C.Api.SchemaObjects.Add($C) | Out-Null
        $C.Api.SchemaObjectsDict[$TypeStruct.Type] = $C

        foreach ($Property in ($ReflectedObj.DeclaredProperties | Where-Object Name -ne "ETag")) {
            $P = Get-SchemaObjectProperty -Property $Property -Api $Api -ApiClass $C
            $C.Properties.Add($P) | Out-Null
        }

        return $C
    }
}

<#
A specific method to extract and format properties when creating schema objects.
#>
function Get-SchemaObjectProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.PropertyType" $_})]
        $Property,

        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "Api" $_})]
        $Api,

        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "ApiClass" $_})]
        $ApiClass
    )

    $P = New-Object ApiMethodProperty #which can then in turn make their own API classes!
    $P.Name = $Property.Name
    $P.Api = $Api
    $P.DiscoveryObj = $ApiClass.DiscoveryObj.properties.($P.Name)
    $P.ReflectedObj = $Property
    $P.Type = Get-ApiPropertyType -Property $P -ApiRootNameSpace $Api.RootNamespace
    $P.Description = Clean-CommentString $P.DiscoveryObj.Description

    if ($P.ReflectedObj.PropertyType.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
        $P.IsSchemaObject = $true
        $P.SchemaObject = New-ApiClass -ReflectedObj $P.ReflectedObj.PropertyType -Api $Api
    }

    return $P
}

#endregion

#region Data Aggregation



<# NOT USED
#instantiate an object with null params
function New-ObjectOfType($Type) {

    #NOTE - we may need to 

    $Constructor = $Type.DeclaredConstructors | select -First 1
    $Params = $Constructor.GetParameters()

    $NulledParams = New-Object System.Collections.ArrayList

    foreach ($P in $Params) {
        $NulledParams.Add($null) | Out-Null
    }

    $obj = New-Object ($Type.FullName) -ArgumentList $NulledParams

    return $obj
} #>


<#
Wrapper of  [MethodInfo].ReturnType.BaseType.GenericTypeArguments[int]
#>
function Get-ApiMethodReturnType {
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.MethodInfo" $_})]
        $Method,
        
        [Parameter(Mandatory=$false)]
        [int]
        $UseReturnTypeGenericInt=0
    )
    return $Method.ReturnType.BaseType.GenericTypeArguments[$UseReturnTypeGenericInt]
}

#endregion

#Todo: Load from nuget json file
function Import-GShellAssemblies($LibraryIndex, $LibraryIndexVersionInfo){
    
    if (-not [string]::IsNullOrWhiteSpace($LibraryIndexVersionInfo.dllPath) -and `
        $LibraryIndexVersionInfo.dllPath -ne "missing" -and `
        $LibraryIndexVersionInfo.dllPath -notlike "*_._") {

        $Assembly = [System.Reflection.Assembly]::LoadFrom($LibraryIndexVersionInfo.dllPath)

        foreach ($D in $LibraryIndexVersionInfo.Dependencies) {

            $VersionNumber = Get-LatestVersionFromRange -VersionRange $D.Versions

            if ($VersionNumber -eq -1) {
                $VersionInfo = $LibraryIndex.GetLibVersionLatest($D.Name)
            } else {
                $VersionInfo = $LibraryIndex.GetLibVersion($D.Name, $VersionNumber)
            }

            Import-GShellAssemblies $LibraryIndex $VersionInfo | Out-Null
        }
    }

    return $Assembly
}

#to be called after loading from discovery and nuget happens. should have a handle on the files at this point
function Invoke-GShellReflection {

    param (
        #The rest json obj, eg a result of Load-RestJsonFile gmail v1
        [PSCustomObject]$RestJson,

        #The full google name of the API, eg Google.Apis.Gmail.v1
        [string]$ApiName,

        #The nuget version of the file, eg 1.30.0.1034
        [string]$ApiFileVersion,

        #Library index, eg Get-LibraryIndex $LibraryIndexRoot -Log $False
        $LibraryIndex
    )
    $AssemblyName = Get-NugetPackageIdFromJson $RestJson

    $LatestVersionInfo = $LibraryIndex.GetLibVersion($ApiName, $ApiFileVersion)

    $Assembly = Import-GShellAssemblies $LibraryIndex $LatestVersionInfo

    $Api = New-Api $Assembly $RestJson

    #TODO - can this just be the root namespace? What about for APIs that are named differently
    $Api.ApiName = $ApiName

    return $api
}

<#
A simple wrapper for the boolean try parse method
#>
function ConvertTo-Bool {
[CmdletBinding()]
    param (
        [string]
        $BoolString
    )

    if ($null -eq $BoolString) {return $null}

    $Out = $null
    if ([bool]::TryParse($BoolString,[ref]$Out)){
        return $Out
    }
}