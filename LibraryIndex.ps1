﻿# Formats JSON in a nicer output format than the built-in ConvertTo-Json does.
#via https://github.com/PowerShell/PowerShell/issues/2736
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
  $indent = 0;
  $previousLine = $null
  $Lines = $json -Split "`r`n"

  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($Lines[$i] -match '[\}\]]') {
        # This line contains  ] or }, decrement the indentation level
        $indent--
    }

    if (-not [string]::IsNullOrWhiteSpace($Lines[$i])) {
        $lines[$i] = ('  ' * $indent) + $Lines[$i].TrimStart().TrimEnd().Replace(':  ', ': ')
    }
    
    if ($Lines[$i] -match '[\{\[]$') {
        # This line contains [ or {, increment the indentation level
        $indent++
    }

    if (-not [string]::IsNullOrWhiteSpace($Lines[$i])) {
        $lines[$i] = $lines[$i] + "`r`n"
    }

  }
  
  $Lines -Join ""
}

function Get-LibraryIndex ($Path, [bool]$Log=$false) {

    Log "Loading or Creating Json Index File" $Log

    $DllPathsJsonPath = [System.IO.Path]::Combine($Path, "LibPaths.json")
    
    if (-not (Test-Path ($DllPathsJsonPath))){
        @{} | ConvertTo-Json | Out-File $DllPathsJsonPath
    }

    $LibraryIndex = Get-Content $DllPathsJsonPath -Raw | ConvertFrom-Json

    $LibraryIndex | Add-Member -MemberType NoteProperty -Name "RootPath" -Value $DllPathsJsonPath -Force

    if (-NOT (Has-ObjProperty $LibraryIndex "Libraries")) {
        $LibraryIndex | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)
    }

    #Save()
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "Save" -Value {
        Save-LibraryIndex $this
    }

    #HasLib(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "HasLib" -Value {
        param([string]$LibName)
        return (Test-LibraryIndexLib $this $LibName)
    }

    #GetLib(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLib" -Value {
        param( [string]$LibName)
        return Get-LibraryIndexLib $this $LibName
    }

    #GetLibAll()
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibAll" -Value {
        return Get-LibraryIndexLibAll $this
    }

    #AddLib(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "AddLib" -Value {
        param( [string]$LibName )
        return Add-LibraryIndexLib $this $LibName
    }

    #GetLibSource(LibName, Source)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibSource" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibSource $this $LibName
    }
    
    #SetLibSource(LibName, Source)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibSource" -Value {
        param([string]$LibName, [ValidateSet("Local","Nuget")][string]$Source)
        return Set-LibraryIndexLibSource $this $LibName $Source
    }

    #GetLibLastVersionBuilt(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibLastVersionBuilt" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibLastVersionBuilt $this $LibName
    }

    #SetLibLastVersionBuilt(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibLastVersionBuilt" -Value {
        param([string]$LibName, [string]$Version = $null)
        return Set-LibraryIndexLibLastVersionBuilt $this $LibName $Version
    }

    #HasLibVersion(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "HasLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return Test-LibraryIndexLibVersion $this $LibName $Version
    }

    #GetLibVersion(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return Get-LibraryIndexLibVersion $this $LibName $Version
    }

    #GetLibVersionAll(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersionAll" -Value {
        param( [string]$LibName)
        return Get-LibraryIndexLibVersionAll $this $LibName
    }

    #GetLibVersionLatest(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersionLatest" -Value {
        param( [string]$LibName)
        return Get-LibraryIndexLibVersionLatest $this $LibName
    }

    #GetLibVersionLatestName(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersionLatestName" -Value {
        param( [string]$LibName)
        return Get-LibraryIndexLibVersionLatestName $this $LibName
    }

    #AddLibVersion(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "AddLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return Add-LibraryIndexLibVersion $this $LibName $Version
    }

    #HasLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "HasLibVersionDependency" -Value {
        param([string]$LibName, [string]$Version,
            [string]$DependencyName, [string]$DependencyVersions)
        return Test-LibraryIndexLibVersionDependency $this $LibName $Version $DependencyName $DependencyVersions
    }

    #GetLibVersionDependencies(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersionDependencies" -Value {
        param([string]$LibName, [string]$Version)
        return Get-LibraryIndexLibVersionDependencies $this $LibName $Version
    }

    #AddLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "AddLibVersionDependency" -Value {
        param([string]$LibName, [string]$Version,
            [string]$DependencyName, [string]$DependencyVersions)
        return Add-LibraryIndexLibVersionDependency $this $LibName $Version $DependencyName $DependencyVersions
    }

    #GetLibVersionDependencyChain(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibVersionDependencyChain" -Value {
        param([string]$LibName, [string]$Version)
        return Get-LibraryIndexLibVersionDependencyChain $this $LibName $Version
    }
    
    Initialize-LibraryIndex $LibraryIndex

    return $LibraryIndex
}

#Save()
function Save-LibraryIndex {
    param($LibraryIndex)

    $LibraryIndex | ConvertTo-Json -Depth 20 | Format-Json | Out-File $LibraryIndex.RootPath -Force
}

function Test-LibraryIndexLib {
    param($LibraryIndex, [string]$LibName)

    return (Has-ObjProperty $LibraryIndex.Libraries $LibName)
}

#GetLib(LibName)
function Get-LibraryIndexLib {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName
}

#GetLibAll()
function Get-LibraryIndexLibAll {
    param($LibraryIndex)

    return $LibraryIndex.Libraries.psobject.Properties.Name
}

#AddLib(LibName)
function Add-LibraryIndexLib {
    param($LibraryIndex, [string]$LibName )

    $L = New-Object PSCustomObject
    $L | Add-Member -MemberType NoteProperty -Name "LastVersionBuilt" -Value $null
    $L | Add-Member -MemberType NoteProperty -Name "Source" -Value $null
    $L | Add-Member -MemberType NoteProperty -Name "Versions" -Value (New-Object psobject)
    $LibraryIndex.Libraries | Add-Member -NotePropertyName $LibName -NotePropertyValue $L
}

#GetLibSource
function Get-LibraryIndexLibSource {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName.Source
}

#SetLibSource
function Set-LibraryIndexLibSource {
    param($LibraryIndex, [string]$LibName, [ValidateSet("Local","Nuget")][string]$Source)

    $LibraryIndex.Libraries.$LibName.Source = $Source
}

#GetLibLastVersionBuilt
function Get-LibraryIndexLibLastVersionBuilt {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName.LastVersionBuilt
}

#SetLibLastVersionBuilt
function Set-LibraryIndexLibLastVersionBuilt {
    param($LibraryIndex, [string]$LibName, $Version = $null)

    $LibraryIndex.Libraries.$LibName.LastVersionBuilt = $Version
}
    
#HasLibVersion(LibName, Version)
function Test-LibraryIndexLibVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    return ($LibraryIndex.HasLib($LibName) -and `
        (Has-ObjProperty $LibraryIndex.GetLib($LibName).Versions $Version))
}

#GetLibVersion(LibName, Version)
function Get-LibraryIndexLibVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ($Version  -eq -1) {
        return $LibraryIndex.GetLibVersionAll($LibName) | sort -Property Name | select -Last 1
    } else {    
        return $LibraryIndex.GetLib($LibName).Versions.$Version
    }
}

#GetLibVersionAll(LibName)
function Get-LibraryIndexLibVersionAll {
    param($LibraryIndex, [string]$LibName)

    return (Get-LibraryIndexLib $LibraryIndex $LibName).Versions.psobject.Properties
}

#GetLibVersionLatest(LibName)
function Get-LibraryIndexLibVersionLatest {
    param($LibraryIndex, [string]$LibName)

    $version = Get-LibraryIndexLibVersionLatestName $LibraryIndex $LibName
    if ($version -ne $null) {
        $result = Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version
    }
    return $result
}

#GetLibVersionLatestName(LibName)
function Get-LibraryIndexLibVersionLatestName {
    param($LibraryIndex, [string]$LibName)

    $version = (Get-LibraryIndexLibVersionAll $LibraryIndex $LibName).name | sort -Descending | select -First 1
        
    return $version
}

#AddLibVersion(LibName, Version)
function Add-LibraryIndexLibVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if (-not (Test-LibraryIndexLib $LibraryIndex $LibName)){
        Add-LibraryIndexLib $LibraryIndex $LibName
    }

    (Get-LibraryIndexLib $LibraryIndex $LibName).Versions | Add-Member -NotePropertyName $Version -NotePropertyValue `
        (New-Object PSCustomObject -Property ([ordered]@{
            "dllPath"=$null
            "xmlPath"=$null
            "Dependencies"=@()
            }))
}

#HasLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
function Test-LibraryIndexLibVersionDependency {
    param($LibraryIndex, [string]$LibName, [string]$Version,
        [string]$DependencyName, [string]$DependencyVersions)

    if ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version)){
        return ((Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).Dependencies `
            | where {$_.Name -eq $DependencyName -and $_.Version -eq $DependencyVersions} `
            -ne $null)
    }

}

#GetLibVersionDependencies(LibName, Version)
function Get-LibraryIndexLibVersionDependencies {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ($LibraryIndex.HasLibVersion($LibName, $Version)){
        return $LibraryIndex.GetLibVersion($LibName, $Version).Dependencies
    }
}

#AddLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
function Add-LibraryIndexLibVersionDependency {
    param($LibraryIndex, [string]$LibName, [string]$Version,
        [string]$DependencyName, [string]$DependencyVersions)

    if (-not ($LibraryIndex.HasLibVersion($LibName, $Version))) {
        $LibraryIndex.AddLibVersion($LibName, $Version)
    }

    if (-not ($LibraryIndex.HasLibVersionDependency($LibName, $Version,
        $DependencyName, $DependencyVersions))) {

        $D = $LibraryIndex.GetLibVersion($LibName, $Version)
                
        $O = New-Object psobject -Property ([ordered]@{
            Name = $DependencyName
            Versions = $DependencyVersions
        })
                
        $D.Dependencies += $O
    }
}

#GetLibVersionDependencyChain(LibName, Version)
function Get-LibraryIndexLibVersionDependencyChain {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    $DependenciesHash = @{}

    if ($LibraryIndex.HasLibVersion($LibName, $Version)){
            
        if (-not $DependenciesHash.ContainsKey($LibName)) {
            $DependenciesHash[$LibName] = $Version
        }

        $Dependencies = $LibraryIndex.GetLibVersion($LibName, $Version).Dependencies
        foreach ($Dependency in $Dependencies) {
            $Version = Get-LatestVersionFromRange $Dependency.Versions
            if  ($version -eq -1) {
                $Version = $LibraryIndex.GetLibVersionLatestName($Dependency.Name)
            }

            $SubDependenciesHash = $LibraryIndex.GetLibVersionDependencyChain($Dependency.Name, $Version)

            foreach ($LibKey in $SubDependenciesHash.Keys) {
                $DependenciesHash[$LibKey] = $SubDependenciesHash[$LibKey]
            }
        }
    }

    return $DependenciesHash
}

function Initialize-LibraryIndex ($LibraryIndex) {
#check for missing files and update the json index
    $ChangedInfo = $false

    foreach ($L in (Get-LibraryIndexLibAll $LibraryIndex)) {
        foreach ($V in (Get-LibraryIndexLibVersionAll $LibraryIndex $L)){
            $Info = Get-LibraryIndexLibVersion $LibraryIndex $L $V.Name
            
            if ($Info.dllPath -notlike "*_._" -AND $Info.dllPath -ne $null) {
                if (-NOT (Test-Path $Info.dllPath)){
                    $Info.dllPath = "missing"
                    $ChangedInfo = $true
                }
            }

            if ($Info.xmlPath -notlike "*_._" -AND -not [string]::IsNullOrWhiteSpace($Info.xmlPath)) {
                if (-NOT (Test-Path $Info.xmlPath)){
                    $Info.xmlPath = "missing"
                    $ChangedInfo = $true
                }
            }
        }
    }

    if ($ChangedInfo) {
        Save-LibraryIndex $LibraryIndex
    }
}