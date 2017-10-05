#region General Functions

function Get-DiscoveryJson ($ApiName) {
    #START HERE - LOAD THE JSON IN FROM A LOCAL FILE
    $RestJson = Get-Content -Path "$env:USERPROFILE\desktop\\Desktop\DiscoveryRestJson\Google.Apis.Discovery.v1.r1.json" | ConvertFrom-Json
}

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
    $NameAndVersion
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
        if ($Matches -ne $null) {
            $this.Name = $Matches[0].Split(".")[0]
            $this.NameAndVersion = $Matches[0]
        }
        
        Get-Resources $this | % {$this.Resources.Add($_) | Out-Null}
    }
}

class ApiResource {
    $Api
    $ParentResource
    $ChildResources = (New-Object System.Collections.ArrayList)

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
    $R.Name = $t.Name -replace "Resource",""
    $R.NameLower = $R.Name.ToLower()[0] + $R.name.Substring(1,$R.name.Length-1)
    $R.FullName = $t.FullName
    $R.Namespace = $t.Namespace

    #TODO - Assign Child Resources (if any)

    $Methods = Get-ApiResourceMethods $T

    $Methods | % {$R.Methods.Add($_) | Out-Null }

    return $R
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

        $Instantiated = 

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

    #$Json = Get-DiscoveryJson $ApiName

    $Api = Get-Api $Assembly

    $Api | Add-Member -MemberType NoteProperty -Name "RestJson" -Value $RestJson

    #proof of concept
    #write-host $Api.Name -ForegroundColor Yellow
    #foreach ($R in $Api.Resources) {
    #    Write-Host (Set-Indent ("{%T}"+$R.Name) 1) -ForegroundColor DarkYellow
    #    foreach ($M in $R.Methods) {
    #        Write-Host (Set-Indent ("{%T}"+$M.Name)  2) -ForegroundColor Green
    #    }
    #}

    return $api
}

$RestJson = Load-RestJsonFile discovery v1

$LibraryIndex = Get-JsonIndex $LibraryIndexRoot

$Api = Invoke-GShellReflection $RestJson $LibraryIndex

#Write-Host $Method.ReflectedObj.ReturnType.FullName -ForegroundColor Green
#$test = New-ObjectOfType $Method.ReflectedObj.ReturnType
