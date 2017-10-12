﻿#region General Functions

function Get-DiscoveryJson ($ApiName) {
    #START HERE - LOAD THE JSON IN FROM A LOCAL FILE
    $RestJson = Get-Content -Path "$env:USERPROFILE\desktop\\Desktop\DiscoveryRestJson\Google.Apis.Discovery.v1.r1.json" | ConvertFrom-Json
}

function Get-ObjProperties ($PSObject) {
    $PSObject.psobject.Properties | % {write-host $_.Name -ForegroundColor Green; Write-Host $PSObject.($_.Name) "`r`n"}
}

function ConvertTo-FirstLower ($String) {
    return $String.ToLower()[0] + $String.Substring(1,$String.Length-1)
}

function ConvertTo-FirstUpper ($String) {
    return $String.ToUpper()[0] + $String.Substring(1,$String.Length-1)
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

function Set-Indent ([string]$String, [int]$TabCount, [string]$TabPlaceholder = "{%T}") {
    return ($String -replace $TabPlaceholder,("`t"*$TabCount))
}

#endregion

#region Classes
class Api {
    $Name
    $NameAndVersion
    $Resources = (New-Object system.collections.arraylist)
    $RootNamespace
    $DataNamespace
    $Version
    $ReflectedObj
    $DiscoveryObj
}

function New-Api ([System.Reflection.Assembly]$Assembly, $RestJson) {
    $api = New-Object Api

    $api.DiscoveryObj = $RestJson
        
    $api.RootNamespace = $Assembly.FullName.Split(",")[0]
    $api.DataNamespace = $api.RootNamespace + ".Data"
    $api.Version = $Assembly.FullName.Split(",")[1].Split("=")[1]
    $api.ReflectedObj = $Assembly

    #Try and find the name
    $Matches = $null
    $Assembly.FullName -match "(?<=Google.Apis.).*(?=, Version)" | Out-Null
    if ($Matches -ne $null) {
        $api.Name = $Matches[0].Split(".")[0]
        $api.NameAndVersion = $Matches[0]
    }
    
    Get-Resources $api | % {$api.Resources.Add($_) | Out-Null}

    return $api
}

class ApiResource {
    $Api
    $ParentResource
    $ChildResources = (New-Object System.Collections.ArrayList)
    $DiscoveryObj

    $Name
    $NameLower
    $FullName
    $Namespace
    $Methods = (New-Object System.Collections.ArrayList)
    $ReflectedObj
}

function New-ApiResource ([Api]$Api, [System.Reflection.PropertyInfo]$Resource) {
    #for whatever reason, can't put this in the constructor with or else it gives a type error

    $t = $Resource.PropertyType

    $R = New-Object ApiResource

    $R.Api = $Api
    $R.ReflectedObj = $t
    $R.Name = ConvertTo-FirstUpper ($t.Name -replace "Resource","")
    $R.NameLower = ConvertTo-FirstLower $R.Name
    $R.FullName = $t.FullName
    $R.Namespace = $t.Namespace

    $R.DiscoveryObj = $Api.DiscoveryObj.resources.($R.Name)
    #TODO - Assign Child Resources (if any)

    $Methods = Get-ApiResourceMethods $R $T

    $Methods | % {$R.Methods.Add($_) | Out-Null }

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

    #Reference to the container resource
    $Resource

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
    $M.ReflectedObj = $Method
    $M.DiscoveryObj = $Resource.DiscoveryObj.methods.($Method.name)

    $M.Name = ConvertTo-FirstUpper $Method.Name
    $M.NameLower = ConvertTo-FirstLower $Method.Name
    $M.Description = $M.DiscoveryObj.description
    $M.ReturnType = Get-ApiMethodReturnType $Method
    
    #get the properties of the virtual method. This may include a body?
    foreach ($P in $Method.GetParameters()) {
        #$M.Parameters.Add($P) | Out-Null
        $M.VirtualParameters.Add((New-ApiMethodProperty $M $P)) | Out-Null
    }
    
    #get the properties of the request class - those missing set methods are generally properties not associated with
    # the api -MethodName, HttpMethod and RestPath. Properties with setters are likely to be those we want to update
    # and send along with the API request
    foreach ($P in ($M.ReflectedObj.ReturnType.DeclaredProperties | where SetMethod -ne $null)){
        $Param = (New-ApiMethodProperty $M $P)
        
        $M.Parameters.Add($Param) | Out-Null
        $M.RequestParameters.Add($Param) | Out-Null
    }

    $M.HasPagedResults = $Method.ReturnType.DeclaredProperties.name -contains "PageToken"

    $M.HasBodyParameter = $M.Parameters.name -contains "body"
    if ($M.HasBodyParameter -eq $true) {
        $M.BodyParameter = $M.Parameters | where name -eq "body"
    }

    return $M
}

class ApiMethodProperty {
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
}

function Get-ApiPropertyTypeShortName($Property, $Method) {
    $Name = $Property.FullName
    
    switch ($Name) {
        "System.String" {return "string"}
        "System.Int32" {return "int"}
        "System.Boolean" {return "bool"}
    }

    $Replaced = $Name -replace ($Method.Resource.Api.RootNamespace + ".")

    return $Replaced
}

function Get-ApiPropertyType ([ApiMethodProperty]$Property) {
    if ($Property.ReflectedObj.PropertyType.Name -eq "Nullable``1"){

        #-replace "``1\[","<" -replace "\]",">"

        $inners = New-Object System.Collections.ArrayList

        foreach ($I in $Property.ReflectedObj.PropertyType.GenericTypeArguments) {
            $inners.Add((Get-ApiPropertyTypeShortName $I $Property.Method)) | Out-Null
        }

        $InnerString = $inners -join ", "

        $Type = "System.Nullable<{0}>" -f $InnerString

        return $type

    } else  {

        return Get-ApiPropertyTypeShortName $Property.ReflectedObj.PropertyType $Property.Method
    }
}

function New-ApiMethodProperty ([ApiMethod]$Method, $Property) {
    $P = New-Object ApiMethodProperty
    $P.Method = $Method
    $P.Name = ConvertTo-FirstUpper $Property.Name
    $P.NameLower = ConvertTo-FirstLower $Property.Name
    $P.ReflectedObj = $Property
    $P.DiscoveryObj = $Method.DiscoveryObj.parameters.($Property.Name)
    $P.Type = Get-ApiPropertyType $P
    $P.Description = $P.DiscoveryObj.Description
    $P.Required = [bool]($P.DiscoveryObj.required)

    return $P
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
    #$Methods = $Resource.DeclaredNestedTypes | where {$_.ImplementedInterfaces.Name -contains "IClientServiceRequest"}
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

#region Templates



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
function Invoke-GShellReflection ($RestJson, $LibraryIndex) {
    
    $AssemblyName = Get-NugetPackageIdFromJson $RestJson

    $LatestVersionInfo = $LibraryIndex.GetLibVersionLatest($AssemblyName)

    $Assembly = Import-GShellAssemblies $LibraryIndex $LatestVersionInfo

    $Api = New-Api $Assembly $RestJson

    return $api
}

#Write-Host $Method.ReflectedObj.ReturnType.FullName -ForegroundColor Green
#$test = New-ObjectOfType $Method.ReflectedObj.ReturnType

#$RestJson = Load-RestJsonFile admin directory_v1
$RestJson = Load-RestJsonFile admin reports_v1
#$RestJson = Load-RestJsonFile discovery v1
$LibraryIndex = Get-JsonIndex $LibraryIndexRoot
$Api = Invoke-GShellReflection $RestJson $LibraryIndex


$Resources = $Api.Resources
$Resource = $Resources[0]
$Methods = $Resource.Methods
$Method = $Methods[1]
$M = $Method
$Init = $M.ReflectedObj.ReturnType.DeclaredMethods | where name -eq "InitParameters"
