#Todo: Load from nuget json file
function Import-GShellAssemblies(){
    foreach ($file in (gci "C:\Users\svarney\Documents\gShell\gShell\gShell\bin\Debug" -Filter "*.dll")){
        [System.Reflection.Assembly]::LoadFrom($file.FullName)
    }
}

function Get-MethodProperties($Method){

}

function Get-ApiSections($Api){

}

function Get-SectionMethods($Section){

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

class Api {
    $Resources = @()
    $Namespace

}

class Resource {
    $Api
    $ParentResource
    $Resources = (New-Object system.collections.arraylist)
    $Namespace
}