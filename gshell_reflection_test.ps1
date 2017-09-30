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

    $Name
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
    $Service = $Api.ReflectedObj.ExportedTypes | where {$_.BaseType.ToString() -eq "Google.Apis.Services.BaseClientService"}
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

        #TODO - Assign Child Resources (if any)

        $Methods = Get-ApiResourceMethods $T

        $Methods | % {$R.Methods.Add($_) | Out-Null }

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
        $M.ReturnType = Get-ApiMethodReturnType $Method
        $Method.GetParameters() | % {$M.Parameters.Add($_) | Out-Null}
        $M.ReflectedObj = $Method

        $Results.Add($M) | Out-Null
    }

    return $Results
}

function Get-Api ($Assembly) {
    $Api = New-Object Api $Assembly

    return $Api
}


function Get-ApiMethodReturnType($Method){
    return $Method.ReturnType.BaseType.GenericTypeArguments[0]
}

$Assembly = [System.Reflection.Assembly]::LoadFrom("C:\Users\svarney\Documents\gShell\gShell\gShell\bin\Debug\Google.Apis.Discovery.v1.dll")

$Api = Get-Api $Assembly

#proof of concept
write-host $Api.Name -ForegroundColor Yellow
foreach ($R in $Api.Resources) {
    Write-Host (Set-Indent ("{%T}"+$R.Name) 1) -ForegroundColor DarkYellow
    foreach ($M in $R.Methods) {
        Write-Host (Set-Indent ("{%T}"+$M.Name) 2) -ForegroundColor Green
    }
}