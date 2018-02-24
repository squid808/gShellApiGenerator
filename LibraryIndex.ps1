# Formats JSON in a nicer output format than the built-in ConvertTo-Json does.
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

    #GetLibNameRedirect
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibNameRedirect" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibNameRedirect $this $LibName
    }

    #SetLibNameRedirect
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibNameRedirect" -Value {
        param([string]$LibName, [string]$RedirectName)
        return Set-LibraryIndexLibNameRedirect $this $LibName $RedirectName
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

    #GetLibLastVersionBuilt(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibLastVersionBuilt" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibLastVersionBuilt $this $LibName
    }

    #SetLibLastVersionBuilt(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibLastVersionBuilt" -Value {
        param([string]$LibName, [string]$Version = $null)
        return Set-LibraryIndexLibLastVersionBuilt $this $LibName $Version
    }

    #GetLibLastSuccessfulVersionBuilt(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibLastSuccessfulVersionBuilt" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibLastSuccessfulVersionBuilt $this $LibName
    }

    #SetLibLastSuccessfulVersionBuilt(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibLastSuccessfulVersionBuilt" -Value {
        param([string]$LibName, [string]$Version = $null)
        return Set-LibraryIndexLibLastSuccessfulVersionBuilt $this $LibName $Version
    }

    #GetLibRestNameAndVersion(LibName)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibRestNameAndVersion" -Value {
        param([string]$LibName)
        return Get-LibraryIndexLibRestNameAndVersion $this $LibName
    }

    #SetLibRestNameAndVersion(LibName, RestNameAndVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibRestNameAndVersion" -Value {
        param([string]$LibName, [string]$RestNameAndVersion)
        return Set-LibraryIndexLibRestNameAndVersion $this $LibName $RestNameAndVersion
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

    #HasLibraryVersionSourceVersion(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "HasLibraryVersionSourceVersion" -Value {
        param([string]$LibName, [string]$Version)
        return Test-LibraryVersionSourceVersion $this $LibName $Version
    }

    #GetLibraryVersionSourceVersion(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibraryVersionSourceVersion" -Value {
        param([string]$LibName, [string]$Version)
        return Get-LibraryVersionSourceVersion $this $LibName $Version
    }

    #SetLibraryVersionSourceVersion(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibraryVersionSourceVersion" -Value {
        param([string]$LibName, [string]$Version, [string]$SourceVersion)
        return Set-LibraryVersionSourceVersion $this $LibName $Version $SourceVersion
    }

    #GetLibraryVersionCmdletCount(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibraryVersionCmdletCount" -Value {
        param([string]$LibName, [string]$Version)
        return Get-LibraryVersionCmdletCount $this $LibName $Version
    }

    #SetLibraryVersionCmdletCount(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibraryVersionCmdletCount" -Value {
        param([string]$LibName, [string]$Version, [int]$CmdletCount)
        return Set-LibraryVersionCmdletCount $this $LibName $Version $CmdletCount
    }

    #HasLibraryVersionSuccessfulGeneration(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "HasLibraryVersionSuccessfulGeneration" -Value {
        param([string]$LibName, [string]$Version)
        return Test-LibraryVersionSuccessfulGeneration $this $LibName $Version
    }

    #GetLibraryVersionSuccessfulGeneration(LibName, Version)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "GetLibraryVersionSuccessfulGeneration" -Value {
        param([string]$LibName, [string]$Version)
        return Get-LibraryVersionSuccessfulGeneration $this $LibName $Version
    }

    #SetLibraryVersionSuccessfulGeneration(LibName, Version, DependencyName, DependencyVersion)
    $LibraryIndex | Add-Member -MemberType ScriptMethod -Name "SetLibraryVersionSuccessfulGeneration" -Value {
        param([string]$LibName, [string]$Version, [bool]$SuccessfulGeneration)
        return Set-LibraryVersionSuccessfulGeneration $this $LibName $Version $SuccessfulGeneration
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

    $LibraryIndex.Libraries.$LibName.LastVersionBuilt = $Version
}

#GetLibLastSuccessfulVersionBuilt
function Get-LibraryIndexLibLastSuccessfulVersionBuilt {
    param($LibraryIndex, [string]$LibName)

    return $LibraryIndex.Libraries.$LibName.LastSuccessfulVersionBuilt
}

#SetLibLastSuccessfulVersionBuilt
function Set-LibraryIndexLibLastSuccessfulVersionBuilt {
    param($LibraryIndex, [string]$LibName, $Version = $null)

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
        return (((Get-LibraryIndexLibVersion $LibraryIndex $LibName $Version).Dependencies `
            | where {$_.Name -eq $DependencyName -and $_.Versions -eq $DependencyVersions}) `
            -ne $null)
    }

    return $false
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

#HasLibraryVersionSourceVersion(LibName, Version)
function Test-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ($LibraryIndex.HasLibVersion($LibName, $Version)){
        $VersionInfo = $LibraryIndex.GetLibVersion($LibName, $Version)
        return (-not [String]::IsNullOrWhiteSpace($VersionInfo.SourceVersion))
    }
}

#GetLibraryVersionSourceVersion(LibName, Version)
function Get-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if (Test-LibraryVersionSourceVersion $LibraryIndex $LibName $Version){
        return $LibraryIndex.GetLibVersion($LibName, $Version).SourceVersion
    }
}

#SetLibraryVersionSourceVersion(LibName, Version, SourceVersion)
function Set-LibraryVersionSourceVersion {
    param($LibraryIndex, [string]$LibName, [string]$Version, [string]$SourceVersion)

    if (-not ($LibraryIndex.HasLibVersion($LibName, $Version))) {
        $LibraryIndex.AddLibVersion($LibName, $Version)
    }

    $VersionInfo = $LibraryIndex.GetLibVersion($LibName, $Version)

    if ($VersionInfo.PSObject.Properties.Name -notcontains "SourceVersion") {
        $VersionInfo | Add-Member -NotePropertyName "SourceVersion" -NotePropertyValue $null
    }

    $VersionInfo.SourceVersion = $SourceVersion
}

#GetLibraryVersionCmdletCount(LibName, Version)
function Get-LibraryVersionCmdletCount {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    return $LibraryIndex.GetLibVersion($LibName, $Version).CmdletCount
}

#SetLibraryVersionCmdletCount(LibName, Version, CmdletCount)
function Set-LibraryVersionCmdletCount {
    param($LibraryIndex, [string]$LibName, [string]$Version, [int]$CmdletCount)

    if (-not ($LibraryIndex.HasLibVersion($LibName, $Version))) {
        $LibraryIndex.AddLibVersion($LibName, $Version)
    }

    $VersionInfo = $LibraryIndex.GetLibVersion($LibName, $Version)

    if ($VersionInfo.PSObject.Properties.Name -notcontains "CmdletCount") {
        $VersionInfo | Add-Member -NotePropertyName "CmdletCount" -NotePropertyValue $null
    }

    $VersionInfo.CmdletCount = $CmdletCount
}

#HasLibraryVersionSuccessfulGeneration(LibName, Version)
function Test-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if ($LibraryIndex.HasLibVersion($LibName, $Version)){
        $VersionInfo = $LibraryIndex.GetLibVersion($LibName, $Version)
        return (-not [String]::IsNullOrWhiteSpace($VersionInfo.SuccessfulGeneration))
    }
}

#GetLibraryVersionSuccessfulGeneration(LibName, Version)
function Get-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version)

    if (Test-LibraryVersionSourceVersion $LibraryIndex $LibName $Version){
        return $LibraryIndex.GetLibVersion($LibName, $Version).SuccessfulGeneration
    }
}

#SetLibraryVersionSuccessfulGeneration(LibName, Version, SourceVersion)
function Set-LibraryVersionSuccessfulGeneration {
    param($LibraryIndex, [string]$LibName, [string]$Version, [bool]$SuccessfulGeneration)

    if (-not ($LibraryIndex.HasLibVersion($LibName, $Version))) {
        $LibraryIndex.AddLibVersion($LibName, $Version)
    }

    $VersionInfo = $LibraryIndex.GetLibVersion($LibName, $Version)

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

    $LibraryIndex.Save()
}