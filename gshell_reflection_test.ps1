#Todo: Load from nuget json file
function Import-GShellAssemblies(){
    foreach ($file in (gci "C:\Users\svarney\Documents\gShell\gShell\gShell\bin\Debug" -Filter "*.dll")){
        [System.Reflection.Assembly]::LoadFrom($file.FullName)
    }
}

#region General Functions

function Get-ObjProperties ($PSObject) {
    $PSObject.psobject.Properties | % {write-host $_.Name -ForegroundColor Green; Write-Host $PSObject.($_.Name) "`r`n"}
}

function Set-Indent ([string]$String, [int]$TabCount, [string]$TabPlaceholder = "{%T}") {
    return ($String -replace $TabPlaceholder,("`t"*$TabCount))
}

#endregion

#region Classes
class Api {
    $Name
    $Resources = (New-Object system.collections.arraylist)
    $RootNamespace
    $DataNamespace
    $Version
    $ReflectedObj

    Api ([System.Reflection.Assembly]$Assembly) {
        $this.RootNamespace = $Assembly.FullName.Split(",")[0]
        $this.DataNamespace = $this.RootNamespace + ".Data"
        $this.Version = $Assembly.FullName.Split(",")[1].Split("=")[1]
        $this.ReflectedObj = $Assembly

        #Try and find the name
        $Matches = $null
        $Assembly.FullName -match "(?<=Google.Apis.).*(?=, Version)" | Out-Null
        if ($Matches -ne $null) {$this.Name = $Matches[0]}
        

        Get-Resources $this | % {$this.Resources.Add($_) | Out-Null}
    }
}

class ApiResource {
    $Api
    $ParentResource
    $ChildResources = (New-Object System.Collections.ArrayList)

    $Name
    $FullName
    $Namespace
    $Methods = (New-Object System.Collections.ArrayList)
    $ReflectedObj
}

class ApiMethod {
    $Resource

    $ReturnType
    $Parameters = (New-Object system.collections.arraylist)
    [string]$Description
    $ReflectedObj
    [bool]$PagedResults
}

class ApiMethodProperty {
    $Method
    
    $Name
    $Type
    $Mandatory
    $Description
    $ReflectedObj
}

#endregion

#Return *all* resources exported from this assembly
function Get-Resources([Api]$Api){
    $Service = $Api.Assembly.ExportedTypes | where {$_.BaseType.ToString() -eq "Google.Apis.Services.BaseClientService"}
    $Resources = $Service.DeclaredProperties | where {$_.GetMethod.ReturnType -like "Google.Apis*"}

    $Results = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $t = $Resource.PropertyType

        $R = New-Object ApiResource

        $R.Api = $Api
        $R.ReflectedObj = $t
        $R.Name = $t.Name
        $R.FullName = $t.FullName
        $R.Namespace = $t.Namespace

        #TODO - Assign Methods
        #TODO - Assign Child Resources (if any)

        $Results.Add($R) | Out-Null
    }

    return $Results
}

#Return the methods from a given resource class
function Get-ApiResourceMethods($Resource){
    #$Methods = $Resource.DeclaredNestedTypes | where {$_.ImplementedInterfaces.Name -contains "IClientServiceRequest"}
    $Methods = $resource.DeclaredMethods | where { `
                $_.IsVirtual -and -not $_.IsFinal -and `
                $_.ReturnType.ImplementedInterfaces.Name -contains "IClientServiceRequest" }

    #Methods where virtual and return type implements IClientServiceRequest
    $Results = New-Object System.Collections.ArrayList

    foreach ($Method in $Methods) {
        $M = New-Object ApiMethod
        $M.Resource = $Resource
        $M.Name = $Method.Name
        $M.ReturnType = $Method.ReturnType
        $Method.GetParameters() | % {$M.Parameters.Add($_) | Out-Null}
        $M.ReflectedObj = $Method
    }
}

function Get-Api ($Assembly) {
    return New-Object Api $Assembly
}

function Get-ApiMethodProperties($Method){

}

function Get-ApiMethodReturnType($Method){

}

$Assembly = [System.Reflection.Assembly]::LoadFrom("C:\Users\svarney\Documents\gShell\gShell\gShell\bin\Debug\Google.Apis.Discovery.v1.dll")

$BaseClientService = $Assembly.ExportedTypes | where {$_.BaseType.ToString() -eq "Google.Apis.Services.BaseClientService"}

$MethodFamiliesCollection = New-Object System.Collections.ArrayList

$BaseClientService.DeclaredProperties | where {$_.PropertyType -like "*Resource"} `
    | % {$MethodFamiliesCollection.Add($_) | Out-Null}

#eventually put in foreach
$TypeMethods = $MethodFamiliesCollection[0]

#GetRest, List
$ApiMethodCalls = $TypeMethods.PropertyType.DeclaredMethods

#eventually put in foreach
$ApiMethodCall = $ApiMethodCalls[0]

#These are the parameters for this method call - includes name and type
$ApiMethodCallParameters = $ApiMethodCall.GetParameters()

<#

Base Client Service, eg DiscoveryService
- derives from BaseClientService
- This is the TYPE found in the ServiceWrapper in gshell's dotnet files, eg:
        public class Discovery : ServiceWrapper<discovery_v1.DiscoveryService>
- CONTAINS a virtual property that has a type of an API class, eg ApisResource - uses Resource naming convention always?

#>