#region General Functions

#Sanitize comment strings to make sure \n is always \r\n
function Clean-CommentString($String) {
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
    if (-not [string]::IsNullOrWhiteSpace($string)){
        return $String.ToLower()[0] + $String.Substring(1,$String.Length-1)
    }
}

function ConvertTo-FirstUpper ($String) {
    if (-not [string]::IsNullOrWhiteSpace($string)){
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
class Api {
    $Name
    $NameLower
    $NameAndVersion
    $NameAndVersionLower
    $Resources = (New-Object System.Collections.ArrayList)
    $ResourcesDict = @{}
    $RootNamespace
    $DataNamespace
    $Version
    $ReflectedObj
    $DiscoveryObj
    $SchemaObjectsUsed = (New-Object System.Collections.ArrayList)
    $HasStandardQueryParams
    $StandardQueryparams = (New-Object System.Collections.ArrayList)
    $StandardQueryParamsBaseType
    $CanUseServiceAccount
    $SchemaObjects = (New-Object System.Collections.ArrayList)
    $SchemaObjectsDict = @{}
    $CmdletBaseType
}

function New-Api ([System.Reflection.Assembly]$Assembly, $RestJson) {
    $api = New-Object Api

    $api.DiscoveryObj = $RestJson
        
    $api.RootNamespace = $Assembly.FullName.Split(",")[0] -replace "\.Admin\.",".admin."
    $api.DataNamespace = $api.RootNamespace + ".Data"
    $api.Version = $api.RootNamespace.Split(".")[-1]
    $api.ReflectedObj = $Assembly

    $api.Name = $Api.RootNamespace.Split(".")[-2]
    $api.NameLower = ConvertTo-FirstLower $Api.Name
    $api.NameAndVersion = $Api.RootNamespace -replace "^Google.Apis.",""
    $api.NameAndVersionLower = ConvertTo-FirstLower $Api.NameAndVersion

    Get-Resources $api | % {$api.Resources.Add($_) | Out-Null}
    $api.Resources | % {$api.ResourcesDict[$_.name] = $_}

    $api.HasStandardQueryParams = Has-ObjProperty $api.DiscoveryObj "parameters"
    
    #TODO - throw error if more than one result?
    foreach ($Param in ($Api.ReflectedObj.ExportedTypes | where {$_.Name -like "*BaseServiceRequest?1" `
                -and $_.BaseType.Name -eq "ClientServiceRequest``1"} | select -ExpandProperty DeclaredProperties) `
                | where Name -notlike "alt")
    {
        $P = New-Object ApiMethodProperty
        $P.Api = $api
        $P.ReflectedObj = $Param
        $P.Name = $Param.Name
        $P.NameLower = ConvertTo-FirstLower $Param.Name
        $P.Type = Get-ApiPropertyType -Property $P
        $DiscoveryName = $Param.CustomAttributes | where AttributeType -like "*RequestParameterAttribute" | `
            select -ExpandProperty ConstructorArguments | select -First 1 -ExpandProperty Value
        $P.Description = $P.Api.DiscoveryObj.parameters.($DiscoveryName).Description
        $Api.StandardQueryParams.Add($P) | Out-Null
    }

    $api.CanUseServiceAccount = (-not $api.RootNamespace.StartsWith("Google.Apis.Discovery") -and `
        -not $api.RootNamespace.StartsWith("Google.Apis.admin"))

    
    if ($api.RootNamespace.StartsWith("Google.Apis.Discovery")) {
        $api.StandardQueryParamsBaseType = "OAuth2CmdletBase" #Todo - double check this?
        $api.CmdletBaseType = "StandardQueryParametersBase"
    } elseif ($api.RootNamespace.StartsWith("Google.Apis.admin")) {
        if ($api.HasStandardQueryParams -eq $true) {
            $api.StandardQueryParamsBaseType = "AuthenticatedCmdletBase"
            $api.CmdletBaseType = "StandardQueryParametersBase"
        } else {
            $api.CmdletBaseType = "AuthenticatedCmdletBase"
        }
    } else {
        if ($api.HasStandardQueryParams -eq $true) {
                
            $api.CmdletBaseType = "StandardQueryParametersBase"

            if ($api.CanUseServiceAccount -eq $true) {
                $api.StandardQueryParamsBaseType = "ServiceAccountCmdletBase"
            } else {
                $api.StandardQueryParamsBaseType = "AuthenticatedCmdletBase"
            }
        } else {
            if ($api.CanUseServiceAccount -eq $true) {
                $api.CmdletBaseType = "ServiceAccountCmdletBase"
            } else {
                $api.CmdletBaseType = "AuthenticatedCmdletBase"
            }
        }
    }

    return $api
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
}

function New-ApiMethod ([ApiResource]$Resource, $Method) {
    $M = New-Object ApiMethod
    $M.Resource = $Resource
    $M.Api = $Resource.Api
    $M.ParentResource = $Resource
    $M.ReflectedObj = $Method
    $M.DiscoveryObj = $Resource.DiscoveryObj.methods.($Method.name)

    $M.Name = ConvertTo-FirstUpper $Method.Name
    $M.NameLower = ConvertTo-FirstLower $Method.Name
    $M.Description = Clean-CommentString $M.DiscoveryObj.description
    $M.ReturnType =  New-ApiMethodProperty $M (Get-ApiMethodReturnType $Method)
    
    if (Has-ObjProperty $M.DiscoveryObj "response") {
        $M.ReturnType.Type = Get-ApiPropertyTypeShortName $M.ReturnType.ReflectedObj.FullName $M.Api
    } else {
        $M.ReturnType.Type = "void"
    }
    
    $ParameterNames = New-Object "System.Collections.Generic.HashSet[string]"

    #get the properties of the virtual method. This may include a body?
    foreach ($P in $Method.GetParameters()) {
        $ParameterNames.Add($P.Name.ToLower()) | Out-Null
        $Param = New-ApiMethodProperty $M $P -ForceRequired $true

        $M.Parameters.Add($Param) | Out-Null
        $M.VirtualParameters.Add($Param) | Out-Null
    }
    
    #get the properties of the request class - those missing set methods are generally properties not associated with
    # the api -MethodName, HttpMethod and RestPath. Properties with setters are likely to be those we want to update
    # and send along with the API request
    foreach ($P in ($M.ReflectedObj.ReturnType.DeclaredProperties | where {$_.SetMethod -ne $null -and $_.Name.ToLower() -ne "pagetoken"})){
        if (-not $ParameterNames.Contains($P.Name.ToLower())) {
            $Param = New-ApiMethodProperty $M $P
        
            $M.Parameters.Add($Param) | Out-Null
            $M.RequestParameters.Add($Param) | Out-Null
        }
    }

    $M.Parameters | % {$M.ParametersDict[$_.Name] = $_ }

    $M.HasPagedResults = $Method.ReturnType.DeclaredProperties.name -contains "PageToken" -and `
                            $M.ReturnType.ReflectedObject.DeclaredProperties.name -contains "NextPageToken"

    #$M.HasBodyParameter = $M.Parameters.name -contains "body"
    #if ($M.HasBodyParameter -eq $true) {
    #    $M.BodyParameter = New-ApiClass $M.ParametersDict.Body
    #}

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

    #The property's reflected type
    $Type

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
}

function Get-ApiPropertyTypeShortName($Name, $Api) {
    
    switch ($Name) {
        "System.String" {return "string"}
        "System.Int32" {return "int"}
        "int32" {return "int"}
        "System.Boolean" {return "bool"}
        "boolean" {return "bool"}
    }

    $Replaced = $Name -replace ($Api.RootNamespace + ".")

    return $Replaced
}

function Get-ApiPropertyType ([ApiMethodProperty]$Property) {
    if ($Property.ReflectedObj.GetType().Name -eq "RuntimeParameterInfo") {
        $RefType = $Property.ReflectedObj.ParameterType
    } else {
        $RefType = $Property.ReflectedObj.PropertyType
    }

    if (@("Nullable``1","Repeatable``1","IList``1") -contains $RefType.Name){

        #-replace "``1\[","<" -replace "\]",">"

        $inners = New-Object System.Collections.ArrayList

        foreach ($I in $RefType.GenericTypeArguments) {
            $innerType = Get-ApiPropertyTypeShortName $I.FullName $Property.Api
            $innerType = $innerType -replace "[+]","."
            $inners.Add($innerType) | Out-Null
        }

        $InnerString = $inners -join ", "

        if ($RefType.Name -eq "Nullable``1") {
            #$Type = "System.Nullable<{0}>" -f $InnerString
            $Type = $InnerString + "?"
        }

        if ($RefType.Name -eq "Repeatable``1") {
            $Type = "Google.Apis.Util.Repeatable<{0}>" -f $InnerString
        }

        if ($RefType.Name -eq "IList``1") {
            $Type = "IList<{0}>" -f $InnerString
        }

        return $type

    } else  {

        return Get-ApiPropertyTypeShortName $RefType.FullName $Property.Api
    }
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
    $P.Type = Get-ApiPropertyType $P
    $P.Description = Clean-CommentString $P.DiscoveryObj.Description
    $P.Required = if ($ForceRequired -eq $true) {$true} else {[bool]($P.DiscoveryObj.required)}
    #TODO - is force required really needed?

    #If this is one of the schema objects
    if ($P.ReflectedObj.ParameterType.ImplementedInterfaces.Name -contains "IDirectResponseSchema") {
        
        $P.IsSchemaObject = $true
        $P.SchemaObject = New-ApiClass -ReflectedObj $P.ReflectedObj.ParameterType -Api $Method.Api

        if ($P.Name -eq "Body") {
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
    $TypeData
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

    $TypeData = Get-ApiPropertyTypeShortName $ReflectedObj.FullName $Api

    if ($Api.SchemaObjectsDict.ContainsKey($TypeData)) {
        return $Api.SchemaObjectsDict[$TypeData]
    } else {

        $C = New-Object ApiClass

        $C.Api = $Api

        $C.ReflectedObj = $ReflectedObj
        $C.Type = $ReflectedObj.Name
        $C.DiscoveryObj = $C.Api.DiscoveryObj.schemas.($C.Type)
        $C.TypeData = $TypeData
        $C.Description = Clean-CommentString $C.DiscoveryObj.description
        $C.Api.SchemaObjects.Add($C) | Out-Null
        $C.Api.SchemaObjectsDict[$C.TypeData] = $C

        foreach ($Property in ($ReflectedObj.DeclaredProperties | where Name -ne "ETag")) {
            $P = New-Object ApiMethodProperty #which can then in turn make their own API classes!
            $P.Name = $Property.Name
            $P.Api = $Api
            $P.DiscoveryObj = $C.DiscoveryObj.properties.($P.Name)
            $P.ReflectedObj = $Property
            #$P.Method = $Parameter.Method
            $P.Type = Get-ApiPropertyType $P
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

#Return *all* resources exported from this assembly
function Get-Resources([Api]$Api){
    $Service = $Api.ReflectedObj.ExportedTypes | where {$_.BaseType.ToString() -eq "Google.Apis.Services.BaseClientService"}
    $Resources = $Service.DeclaredProperties | where {$_.GetMethod.ReturnType -like "Google.Apis*"}

    $Results = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $R = New-ApiResource $Api $Resource

        $Results.Add($R) | Out-Null
    }

    return $Results
}

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
}

function Get-ApiResourceMethods($Resource, $ResourceType){
    $Methods = $ResourceType.DeclaredMethods | where { `
                $_.IsVirtual -and -not $_.IsFinal -and `
                $_.ReturnType.ImplementedInterfaces.Name -contains "IClientServiceRequest" }

    #Methods where virtual and return type implements IClientServiceRequest
    $Results = New-Object System.Collections.ArrayList

    foreach ($Method in $Methods) {
        $M = New-ApiMethod $resource $method

        $Results.Add($M) | Out-Null
    }

    return $Results
}

function Get-ApiMethodReturnType($Method){
    return $Method.ReturnType.BaseType.GenericTypeArguments[0]
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
        [PSCustomObject]$RestJson,

        [string]$ApiName,

        [string]$ApiFileVersion,

        $LibraryIndex
    )
    $AssemblyName = Get-NugetPackageIdFromJson $RestJson

    $LatestVersionInfo = $LibraryIndex.GetLibVersion($ApiName, $ApiFileVersion)

    $Assembly = Import-GShellAssemblies $LibraryIndex $LatestVersionInfo

    $Api = New-Api $Assembly $RestJson

    return $api
}

#Write-Host $Method.ReflectedObj.ReturnType.FullName -ForegroundColor Green
#$test = New-ObjectOfType $Method.ReflectedObj.ReturnType

#$RestJson = Load-RestJsonFile admin directory_v1
#$RestJson = Load-RestJsonFile admin reports_v1
#$RestJson = Load-RestJsonFile discovery v1
#$LibraryIndex = Get-JsonIndex $LibraryIndexRoot
#$Api = Invoke-GShellReflection $RestJson $LibraryIndex
#
#
#$Resources = $Api.Resources
#$Resource = $Resources[0]
#$Methods = $Resource.Methods
#$Method = $Methods[1]
#$M = $Method
#$Init = $M.ReflectedObj.ReturnType.DeclaredMethods | where name -eq "InitParameters"
