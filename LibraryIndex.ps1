# Formats JSON in a nicer output format than the built-in ConvertTo-Json does.
#via https://github.com/PowerShell/PowerShell/issues/2736
function Format-Json {

    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$json
    )

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

<#
Loads or creates the library index file at the given path with a default file name
#>
function Load-LibraryIndexFile {
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $Path
    )
    $DllPathsJsonPath = [System.IO.Path]::Combine($Path, "LibPaths.json")
    
    if (-not (Test-Path ($DllPathsJsonPath))){
        @{} | ConvertTo-Json | Out-File $DllPathsJsonPath
    }

    $LibraryIndex = Get-Content $DllPathsJsonPath -Raw | ConvertFrom-Json

    $LibraryIndex.PSObject.TypeNames.Add("LibraryIndex")

    $LibraryIndex | Add-Member -MemberType NoteProperty -Name "RootPath" -Value $DllPathsJsonPath -Force

    return $LibraryIndex
}

function Get-LibraryIndex ($Path, [bool]$Log=$false) {

    Log "Loading or Creating Json Index File" $Log

    $LibraryIndex = Load-LibraryIndexFile $Path


    if (-NOT (Has-ObjProperty $LibraryIndex "Libraries")) {
        $LibraryIndex | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)
    }

    #AddLibVersion(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "AddLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return Add-LibraryIndexLibVersion $this $LibName $Version
    }

    #TODO - combine this with Load-LibraryIndex?

    Initialize-LibraryIndex $LibraryIndex

    return $LibraryIndex
}

#region Library Object Functions
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
    $L | Add-Member -MemberType NoteProperty -Name "LastSuccessfulVersionBuilt" -Value $null
    $L | Add-Member -MemberType NoteProperty -Name "LastVersionBuilt" -Value $null
    $L | Add-Member -MemberType NoteProperty -Name "Source" -Value $null
    $L | Add-Member -MemberType NoteProperty -Name "Versions" -Value (New-Object psobject)
    $LibraryIndex.Libraries | Add-Member -NotePropertyName $LibName -NotePropertyValue $L
}


#GetLibNameRedirect
function Get-LibraryIndexLibNameRedirect {
    param($LibraryIndex, [string]$RedirectName)

    return $LibraryIndex.Libraries.$LibName.RedirectName
}

#SetLibNameRedirect
function Set-LibraryIndexLibNameRedirect {
    param($LibraryIndex, [string]$LibName, [string]$RedirectName)

    if (-not (Test-LibraryIndexLib -LibraryIndex $LibraryIndex -LibName $LibName)) {
        Add-LibraryIndexLib -LibraryIndex $LibraryIndex -LibName $LibName
    }

    $LibraryIndex.Libraries.$LibName | Add-Member -NotePropertyName "RedirectName" -NotePropertyValue $RedirectName

    if (-not (Test-LibraryIndexLib -LibraryIndex $LibraryIndex -LibName $RedirectName)) {
        Add-LibraryIndexLib -LibraryIndex $LibraryIndex -LibName $RedirectName
    }
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

    if ($LibraryIndex.Libraries.$LibName.PSObject.Properties.Name -notcontains "LastVersionBuilt") {
        $LibraryIndex.Libraries.$LibName | add-member -Name "LastVersionBuilt" -MemberType NoteProperty -Value $null
    }

    $LibraryIndex.Libraries.$LibName.LastVersionBuilt = $Version
}

#GetLibLastSuccessfulVersionBuilt
function Get-LibraryIndexLibLastSuccessfulVersionBuilt {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName.LastSuccessfulVersionBuilt
}

#SetLibLastSuccessfulVersionBuilt
function Set-LibraryIndexLibLastSuccessfulVersionBuilt {
    param($LibraryIndex, [string]$LibName, $Version)

    if ($LibraryIndex.Libraries.$LibName.PSObject.Properties.Name -notcontains "LastSuccessfulVersionBuilt") {
        $LibraryIndex.Libraries.$LibName | add-member -Name "LastSuccessfulVersionBuilt" -MemberType NoteProperty -Value $null
    }

    $LibraryIndex.Libraries.$LibName.LastSuccessfulVersionBuilt = $Version
}

#GetLibRestNameAndVersion
function Get-LibraryIndexLibRestNameAndVersion {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName.RestNameAndVersion
}

#SetLibRestNameAndVersion
function Set-LibraryIndexLibRestNameAndVersion {
    param($LibraryIndex, [string]$LibName, [string]$RestNameAndVersion)

    if (-not ( Test-LibraryIndexLib $LibraryIndex $LibName)) {
        Add-LibraryIndexLib $LibraryIndex $LibName
    }

    if (-not (Has-ObjProperty $LibraryIndex.Libraries.$LibName "RestNameAndVersion")) {
        $LibraryIndex.Libraries.$LibName | Add-Member -NotePropertyName "RestNameAndVersion" -NotePropertyValue $null
    }

    $LibraryIndex.Libraries.$LibName.RestNameAndVersion = $RestNameAndVersion
}
    
#HasLibVersion(LibName, Version)
function Test-LibraryIndexLibVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    return ((Test-LibraryIndexLib $LibraryIndex $LibName) -and `
        (Has-ObjProperty (Get-LibraryIndexLib $LibraryIndex $LibName).Versions $Version))
}

#GetLibVersion(LibName, Version)
function Get-LibraryIndexLibVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ($Version  -eq -1) {
        return (Get-LibraryIndexLibVersionAll $LibraryIndex $LibName) | sort -Property Name | select -Last 1
    } else {    
        return (Get-LibraryIndexLib $LibraryIndex $LibName).Versions.$Version
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
        return (((Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).Dependencies `
            | where {$_.Name -eq $DependencyName -and $_.Versions -eq $DependencyVersions}) `
            -ne $null)
    }

    return $false
}

#GetLibVersionDependencies(LibName, Version)
function Get-LibraryIndexLibVersionDependencies {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version)){
        return (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).Dependencies
    }
}

#AddLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
function Add-LibraryIndexLibVersionDependency {
    param($LibraryIndex, [string]$LibName, [string]$Version,
        [string]$DependencyName, [string]$DependencyVersions)

    if (-not ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version))) {
        (Add-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
    }

    if (-not ((Test-LibraryIndexLibVersionDependency $LibraryIndex $LibName $Version,
        $DependencyName, $DependencyVersions))) {

        $D = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
                
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

    if ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version)){
            
        if (-not $DependenciesHash.ContainsKey($LibName)) {
            $DependenciesHash[$LibName] = $Version
        }

        $Dependencies = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).Dependencies
        foreach ($Dependency in $Dependencies) {
            $Version = Get-LatestVersionFromRange $Dependency.Versions
            if  ($version -eq -1) {
                $Version = (Get-LibraryIndexLibVersionLatestName $LibraryIndex $Dependency.Name)
            }

            $SubDependenciesHash = (Get-LibraryIndexLibVersionDependencyChain $LibraryIndex $Dependency.Name, $Version)

            foreach ($LibKey in $SubDependenciesHash.Keys) {
                $DependenciesHash[$LibKey] = $SubDependenciesHash[$LibKey]
            }
        }
    }

    return $DependenciesHash
}

#HasLibraryVersionSourceVersion(LibName, Version)
function Test-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version)){
        $VersionInfo = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
        return (-not [String]::IsNullOrWhiteSpace($VersionInfo.SourceVersion))
    }
}

#GetLibraryVersionSourceVersion(LibName, Version)
function Get-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if (Test-LibraryVersionSourceVersion $LibraryIndex $LibName $Version){
        return (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).SourceVersion
    }
}

#SetLibraryVersionSourceVersion(LibName, Version, SourceVersion)
function Set-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version, [string]$SourceVersion)

    if (-not ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version))) {
        (Add-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
    }

    $VersionInfo = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)

    if ($VersionInfo.PSObject.Properties.Name -notcontains "SourceVersion") {
        $VersionInfo | Add-Member -NotePropertyName "SourceVersion" -NotePropertyValue $null
    }

    $VersionInfo.SourceVersion = $SourceVersion
}

#GetLibraryVersionCmdletCount(LibName, Version)
function Get-LibraryVersionCmdletCount {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    return (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).CmdletCount
}

#SetLibraryVersionCmdletCount(LibName, Version, CmdletCount)
function Set-LibraryVersionCmdletCount {
    param($LibraryIndex, [string]$LibName, [string]$Version, [int]$CmdletCount)

    if (-not ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version))) {
        (Add-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
    }

    $VersionInfo = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)

    if ($VersionInfo.PSObject.Properties.Name -notcontains "CmdletCount") {
        $VersionInfo | Add-Member -NotePropertyName "CmdletCount" -NotePropertyValue $null
    }

    $VersionInfo.CmdletCount = $CmdletCount
}

#HasLibraryVersionSuccessfulGeneration(LibName, Version)
function Test-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version)){
        $VersionInfo = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
        return (-not [String]::IsNullOrWhiteSpace($VersionInfo.SuccessfulGeneration))
    }
}

#GetLibraryVersionSuccessfulGeneration(LibName, Version)
function Get-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if (Test-LibraryVersionSourceVersion $LibraryIndex $LibName $Version){
        return (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).SuccessfulGeneration
    }
}

#SetLibraryVersionSuccessfulGeneration(LibName, Version, SourceVersion)
function Set-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version, [bool]$SuccessfulGeneration)

    if (-not ((Test-LibraryIndexLibVersion $LibraryIndex $LibName $Version))) {
        (Add-LibraryIndexLibVersion $LibraryIndex $LibName $Version)
    }

    $VersionInfo = (Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version)

    if ($VersionInfo.PSObject.Properties.Name -notcontains "SuccessfulGeneration") {
        $VersionInfo | Add-Member -NotePropertyName "SuccessfulGeneration" -NotePropertyValue $null
    }

    $VersionInfo.SuccessfulGeneration = $SuccessfulGeneration
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

function Update-Paths ($LibraryIndex, $NewDllRootPath) {
    foreach ($Library in $LibraryIndex.Libraries.PSObject.Properties.Name) {
        foreach ($Version in $LibraryIndex.Libraries.$Library.Versions.PSObject.Properties.Name) {
            $VInfo = $LibraryIndex.Libraries.$Library.Versions.$Version

            if ($VInfo.dllPath -eq "missing") {
                $AssumedPath = [System.IO.Path]::Combine($NewDllRootPath, $Library, $Version)

                if ((test-path $AssumedPath)) {
                    $dllPath = [System.IO.Path]::Combine($AssumedPath, ($Library + ".dll"))

                    if ((Test-Path $dllPath)) {
                        $VInfo.dllPath = $dllPath
                    }

                    $xmlPath = [System.IO.Path]::Combine($AssumedPath, ($Library + ".xml"))

                    if ((Test-Path $xmlPath)) {
                        $VInfo.xmlPath = $xmlPath
                    }
                }
            }
        }
    }

    Save-LibraryIndex $LibraryIndex
}
#endregion