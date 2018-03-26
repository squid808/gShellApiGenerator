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

            if ($Object -isnot $Type -and $Object.PSObject.TypeNames -notcontains $Type) {
                return $false
            }
        }

        return $true
    } else {
        foreach ($Type in $Types) {

            if ($Object -is $Type -or $Object.PSObject.TypeNames -contains $Type) {
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

<# Retrieves the list of standard query parameters for the provided API
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
        [ValidateNotNull()]
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

#Pull out the scopes from the Api and return objects in a collection
function Get-ApiScopes {
    [CmdletBinding()]
    param (
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        $Assembly,

        #The api's json information from the Google Discovery API
        [Parameter(Mandatory=$true)]
        $RestJson
    )

    $Results = New-Object System.Collections.ArrayList

    $Scopes = $Assembly.ExportedTypes | where Name -eq Scope

    #set the scopes
    if  ($Scopes -ne $null) {
        foreach ($D in ($Scopes | select -ExpandProperty DeclaredFields)){
            $S = new-object ApiScope
            $S.Name = $D.Name
            $S.Uri = $D.GetValue($D)
            $S.Description = $RestJson.auth.oauth2.scopes.($S.Uri).description
            $Results.Add($S) | Out-Null
        }
    } else {
        #Todo - will this break the discovery API?
        throw "No scopes found in the assembly, cannot proceed."
    }

    return ,$Results
}

#Return *all* resources exported from this assembly
function Get-Resources {
    [CmdletBinding()]
    param (
        #The reflected assembly for the api
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-ObjectType "System.Reflection.Assembly" $_})]
        $Assembly
    )

    $Service = $Assembly.ExportedTypes | where {$_.BaseType.ToString() -eq "Google.Apis.Services.BaseClientService"}
    $Resources = $Service.DeclaredProperties | where {$_.GetMethod.ReturnType -like "Google.Apis*"}

    $Results = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $R = New-ApiResource $Api $Resource

        $Results.Add($R) | Out-Null
    }

    return ,$Results
}

class ApiResource {
    $Api
    $ParentResource
    $ChildResources = (New-Object System.Collections.ArrayList)
    $ChildResourcesDict = @{}
    $DiscoveryObj

    $Name
    $NameLower
    $FullName
    $Namespace
    $Methods = (New-Object System.Collections.ArrayList)
    $MethodsDict = @{}
    $ReflectedObj
}

function New-ApiResource ([Api]$Api, [System.Reflection.PropertyInfo]$Resource, [ApiResource]$ParentResource=$null) {

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
        $R.DiscoveryObj = $R.ParentResource.DiscoveryObj.resources.($R.Name)
    } else {
        $R.DiscoveryObj = $Api.DiscoveryObj.resources.($R.Name)
    }
    
    #Handle Children Resources
    if ($t.DeclaredProperties -ne $null -and $t.DeclaredProperties.Count -gt 0) {
        foreach ($CR in $t.DeclaredProperties) {
            $ChildR = New-ApiResource $Api $CR $R
            $R.ChildResources.Add($ChildR) | Out-Null
            $R.ChildResourcesDict[$ChildR.Name] = $ChildR
        }
    }

    $Methods = Get-ApiResourceMethods $R $T

    $Methods | % {$R.Methods.Add($_) | Out-Null }
    $Methods | % {$R.MethodsDict[$_.Name] = $_}

    return $R
}

class ApiMethod {
<#
Remarks - The api method call is broken up in to two parts in the underlying code:
    The Virtual Method
        - a method that returns an object of type of the request class
        - is of a virtual type
        - parameters are almost always the required parameters for the API call
    The Request Class
        - a class that contains properties for each API parameter, including those from the virtual method
        - properties include custom attributes that indicate the parameter name and parameter type (path, query, custom)
#>
    #Reference to the main Api object
    $Api

    #Reference to the container resource
    $Resource

    #Reference to the container resource
    $ParentResource

    #The name of the method derived from the Virtual method
    $Name

    #The name of the method derived from the Virtual method in first-lower case
    $NameLower

    #The type ultimately returned by the api call itself, not the method that returns a request type
    $ReturnType

    #Are the results paged
    [bool]$HasPagedResults

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

    [string]$MethodVerb

    [string]$MethodNoun
}

function New-ApiMethod ([ApiResource]$Resource, $Method, $UseReturnTypeGenericInt=0) {
    $M = New-Object ApiMethod
    $M.Resource = $Resource
    $M.Api = $Resource.Api
    $M.ParentResource = $Resource
    $M.ReflectedObj = $Method
    $M.DiscoveryObj = $Resource.DiscoveryObj.methods.($Method.name)

    $M.Name = ConvertTo-FirstUpper $Method.Name
    $M.NameLower = ConvertTo-FirstLower $Method.Name
    $M.Description = Clean-CommentString $M.DiscoveryObj.description
    $M.ReturnType =  New-ApiMethodProperty $M (Get-ApiMethodReturnType $Method -UseReturnTypeGenericInt $UseReturnTypeGenericInt)
    
    $M.MethodVerb = Get-MCVerb $M.Name
    $M.MethodNoun = $Noun = "G" + $M.Api.Name + (ConvertTo-FirstUpper $M.Api.Version) + `
        (Get-ParentResourceChain -MethodOrResource $M -JoinChar "")

    #TODO - adjust this, where and when is it called?
    if (Has-ObjProperty $M.DiscoveryObj "response") {
        #$M.ReturnType.Type = Get-ApiPropertyTypeShortName $M.ReturnType.ReflectedObj.FullName $M.Api
    } elseif ($M.ReturnType.Name -eq "String") {
        #Found in media downloads
        $M.ReturnType.Type = New-BasicTypeStruct string
    } else {
        $M.ReturnType.Type = New-BasicTypeStruct void
    }
    
    $ParameterNames = New-Object "System.Collections.Generic.HashSet[string]"

    #get the properties of the virtual method. This may include a body?
    foreach ($P in ($Method.GetParameters() | where {$Api.StandardQueryparams.Name -notcontains $_.Name})) {
        $ParameterNames.Add($P.Name.ToLower()) | Out-Null
        $Param = New-ApiMethodProperty $M $P -ForceRequired $true

        $M.Parameters.Add($Param) | Out-Null
        $M.VirtualParameters.Add($Param) | Out-Null
    }
    
    #get the properties of the request class - those missing set methods are generally properties not associated with
    # the api -MethodName, HttpMethod and RestPath. Properties with setters are likely to be those we want to update
    # and send along with the API request
    foreach ($P in ($M.ReflectedObj.ReturnType.DeclaredProperties | where {`
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

    $M.Parameters | % {$M.ParametersDict[$_.Name] = $_ }

    $M.HasPagedResults = $Method.ReturnType.DeclaredProperties.name -contains "PageToken" -and `
                            $M.ReturnType.ReflectedObject.DeclaredProperties.name -contains "NextPageToken"

    return $M
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

function Get-ApiPropertyTypeShortName($Name, $Api) {
    

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

    $Replaced = $Name -replace ($Api.RootNamespace + ".")

    $Replaced = $Replaced -replace "[+]","."

    return $Replaced
}

function New-BasicTypeStruct{
    param (
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

function Get-ApiPropertyTypeBasic {

    param
    (
        $RefType,
        $Api
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
    $TypeStruct.Type = $RefType.FullName -replace ($Api.RootNamespace + ".") -replace "[+]","."
    $TypeStruct.FullyQualifiedType = $RefType.FullName -replace "[+]","."
    $TypeStruct.HelpDocShortType = $TypeStruct.Type.Split(".")[-1]
    $TypeStruct.HelpDocLongType = $TypeStruct.FullyQualifiedType

    return $TypeStruct
}

function Get-ApiPropertyType {
    param (
        [Parameter(ParameterSetName="property")]
        [ApiMethodProperty]$Property,

        [Parameter(ParameterSetName="runtimetype")]
        [System.Type]$RuntimeType,

        [Parameter(ParameterSetName="runtimetype")]
        $Api#,

        #$GenericInners = $null
    )
    if ($PSCmdlet.ParameterSetName -eq "property") {
        if ($Property.ReflectedObj.GetType().Name -eq "RuntimeParameterInfo") {
            $RefType = $Property.ReflectedObj.ParameterType
        } else {
            $RefType = $Property.ReflectedObj.PropertyType
        }

        $Api = $Property.Api
    } else {
        $RefType = $RuntimeType
    }

    #Make sure we're not making a property that is declared as a subclass or object (struct, enum) within a generic class without providing the
    #generic type for said parent class.
    if ($RefType.UnderlyingSystemType -ne $Null -and $RefType.DeclaringType -ne $Null) {
        if ($RefType.UnderlyingSystemType.ToString().Contains("+") -and $RefType.DeclaringType.IsGenericType){
            #$parentType = Get-ApiPropertyType -RuntimeType $RefType.DeclaringType -Api $Api -GenericInners "object"
            #$Type = $parentType + "." + $Type
            return $null
        }
    }

    #if null, return it right here and now
    if ([string]::IsNullOrWhiteSpace($RefType.Name) -and [string]::IsNullOrWhiteSpace($RefType.FullName)) { return $null }
    
    #is this a generic type? nullable, list, etc
    if (-not [string]::IsNullOrWhiteSpace($RefType.Name) -and $RefType.Name.Contains("``")) {
        
        $TypeStruct = New-Object ApiPropertyTypeStruct

        $inners = New-Object System.Collections.ArrayList
        $InnerTypeStruct = New-Object ApiPropertyTypeStruct

        foreach ($I in $RefType.GenericTypeArguments) {
            if ($I.GetType().Name -eq "RuntimeType") {
                $InnerTypeStruct = Get-ApiPropertyType -RuntimeType $I -Api $Api
                $inners.Add
            } else {
                $InnerTypeStruct = Get-ApiPropertyTypeBasic $I $Api
            }

            #if (-not [string]::IsNullOrWhiteSpace($InnerType)) {
            if ($InnerTypeStruct -ne $null) {
                $TypeStruct.InnerTypes.Add($InnerTypeStruct) | Out-Null
            }
        }

        #if ($GenericInners -ne $Null) {
        #    $GenericInners | % {$inners.Add($_) | Out-Null}
        #}

        #don't return any generics that don't have anything inside
        if ($TypeStruct.InnerTypes.Count -eq 0) { return $null }
        
        #$InnerString = $inners -join ", "
        
        if ($TypeStruct.InnerTypes.Count -eq 1) {
            if ($RefType.Name -eq "Repeatable``1") {
                $GenericInnerTypes = $TypeStruct.InnerTypes
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
            
            $TypeStruct = Get-ApiPropertyTypeBasic $RefType $Api
        } else {
            #TODO: when does this happen?
            $TypeStruct.Type = (Get-ApiPropertyTypeBasic $RefType $Api)
            throw "ReflectionTest: RefType FullName is null, please revise"
        }
    }

    return $TypeStruct
}

function New-ApiMethodProperty {
#[CmdletBinding(DefaultParameterSetName = 'FromMethod')]

    Param (
        #[Parameter(ParameterSetName = 'FromMethod')]
        [ApiMethod]$Method,
        
        $Property,
        
        [bool]$ForceRequired = $false
    )
    $P = New-Object ApiMethodProperty
    $P.Method = $Method
    $P.Api = $Method.Api
    $P.Name = ConvertTo-FirstUpper $Property.Name
    $P.NameLower = ConvertTo-FirstLower $Property.Name
    $P.ReflectedObj = $Property
    $P.DiscoveryObj = $Method.DiscoveryObj.parameters.($Property.Name)
    if ($P.ReflectedObj.GetType().Name -eq "RuntimeType") {
        $P.Type = Get-ApiPropertyType -RuntimeType $P.ReflectedObj -Api $Api
    } else {
        $P.Type = Get-ApiPropertyType -Property $P
    }

    if ($P.Type.FullyQualifiedType -like "*Download.IMediaDownloader"){
        #if ($Method.ReturnType.Type -eq "void") {
            $P.Method.SupportsMediaDownload = $true
        #}
        $P.ShouldIncludeInTemplates = $false
    } elseif ($P.Type -eq $Null) {
        $P.ShouldIncludeInTemplates = $false
    }
    
    $P.Description = Clean-CommentString $P.DiscoveryObj.Description
    if ([string]::IsNullOrWhiteSpace($P.Description)){
        $P.Description = "Description for object of type {0} is unavailable." -f $P.Type.HelpDocLongType
    }

    $P.Required = if ($ForceRequired -eq $true) {$true} else {[bool]($P.DiscoveryObj.required)}
    #TODO - is force required really needed?

    #If this is one of the schema objects
    if ($P.ReflectedObj.ParameterType.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
        
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

    Param (
        $ReflectedObj,
        $Api
    )

    #$TypeData = Get-ApiPropertyTypeShortName $ReflectedObj.FullName $Api
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
        #$C.TypeData = $TypeData
        $C.Description = Clean-CommentString $C.DiscoveryObj.description
        $C.Api.SchemaObjects.Add($C) | Out-Null
        $C.Api.SchemaObjectsDict[$TypeStruct.Type] = $C

        foreach ($Property in ($ReflectedObj.DeclaredProperties | where Name -ne "ETag")) {
            $P = New-Object ApiMethodProperty #which can then in turn make their own API classes!
            $P.Name = $Property.Name
            $P.Api = $Api
            $P.DiscoveryObj = $C.DiscoveryObj.properties.($P.Name)
            $P.ReflectedObj = $Property
            #$P.Method = $Parameter.Method
            $P.Type = Get-ApiPropertyType -Property $P
            $P.Description = Clean-CommentString $P.DiscoveryObj.Description

            if ($P.ReflectedObj.PropertyType.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
                $P.IsSchemaObject = $true
                $P.SchemaObject = New-ApiClass -ReflectedObj $P.ReflectedObj.PropertyType -Api $Api
            }

            foreach ($I in $P.ReflectedObj.PropertyType.GenericTypeArguments) {
                if  ($I.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
                    New-ApiClass $I $Api | Out-Null
                }
            }

            $C.Properties.Add($P) | Out-Null
        }

        return $C
    }
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

function Get-ApiResourceMethods($Resource, $ResourceType){
    $AllMethods = $ResourceType.DeclaredMethods | where {$_.IsVirtual -and -not $_.IsFinal}

    #Sort out standard methods first - this will not gather upload methods yet
    $Methods = $AllMethods | where {$_.ReturnType.ImplementedInterfaces.Name -contains "IClientServiceRequest"}
    
    #Methods where virtual and return type implements IClientServiceRequest
    $Results = New-Object System.Collections.ArrayList

    foreach ($Method in $Methods) {
        $M = New-ApiMethod $resource $method

        $Results.Add($M) | Out-Null
    }
    
    #now process methods that have a file upload option
    foreach ($Method in ($AllMethods | where {$_.ReturnType.BaseType -like "Google.Apis.Upload.ResumableUpload*"})) {
        $Parameters = $Method.GetParameters()
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
            $BuiltMethod = $Results | where Name -eq $Method.Name
            $BuiltMethod.UploadMethod = $M
        }
    }

    return $Results
}

function Get-ApiMethodReturnType($Method, $UseReturnTypeGenericInt=0){
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