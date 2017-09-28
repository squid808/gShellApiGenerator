add-type -assembly System.IO.Compression
add-type -assembly System.IO.Compression.FileSystem

function Log ($Message, [bool]$ShouldLog=$false) {
    if ($ShouldLog) {
        Write-Host $Message -ForegroundColor Green
    }
}

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
#via https://github.com/PowerShell/PowerShell/issues/2736
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
  $indent = 0;
  ($json -Split '\n' |
    % {
      if ($_ -match '[\}\]]') {
        # This line contains  ] or }, decrement the indentation level
        $indent--
      }
      $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
      if ($_ -match '[\{\[]') {
        # This line contains [ or {, increment the indentation level
        $indent++
      }
      $line
  }) -Join "`n"
}

function Has-Property ($Object, $Property) {
    $Object.psobject.Properties.name -contains $Property
}

function SearchForNugetPackage($SearchServiceUri, $Package, $IsExactPackageId=$true, [bool]$Log=$false){
    
    Log "Searching for Package $Package" $Log

    if ($IsExactPackageId) {$PackageSpecifier="packageid:"}
    $Uri = ("{0}?q={1}{2}&prerelease=false&includeDelisted=false" -f $SearchServiceUri, $PackageSpecifier, $Package)
    return Invoke-RestMethod $Uri
}

function Get-CatalogEntry ($Package, $Author = $null, $Version = $null, $IsExactPackageId = $true, [bool]$Log=$false) {

    Log ("Retrieving Catalog Entry for {0} version [{1}], by author [{2}]" -f $Package, $Version, $Author) $Log

    #if we can determine the packageid exactly (Google.Apis.Discovery.v1) then use packageid, otherwise if it's missing part (like v1) just use the name
    $SearchResults = SearchForNugetPackage $SearchServiceUri $Package -IsExactPackageId $IsExactPackageId
    
    $VersionInfo = $SearchResults.Data

    if ($Author -ne $null) {
        $VersionInfo = $VersionInfo | where {$_.authors.Contains($Author)}
    }

    if ($Version -eq $null -or $Version -eq -1) {
        $VersionInfo = $VersionInfo | select -ExpandProperty versions | select -Last 1
    } else {
        $VersionInfo = $VersionInfo | select -ExpandProperty versions | where {$_.version -eq $Version}
    }

    $VersionPackageInfo = Invoke-RestMethod $VersionInfo.'@id'

    $CatalogEntry = Invoke-RestMethod $VersionPackageInfo.catalogEntry

    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "packageInfo" -Value $VersionPackageInfo

    return $CatalogEntry
}

function Get-DependenciesOf($CatalogEntry, $JsonHash, $CatalogHash = $null, [bool]$Log=$false){
    
    Log ("Retrieving Dependencies for {0}" -f $CatalogEntry.id) $Log

    #Keyed by library, then version. value = catalog entry
    if  ($CatalogHash -eq $null) {
        $CatalogHash = @{}
    }

    if (-NOT $CatalogHash.ContainsKey($CatalogEntry.id)) {
        $CatalogHash[$CatalogEntry.id] = @{}
    }

    if (-NOT $CatalogHash[$CatalogEntry.id].ContainsKey($CatalogEntry.version)) {
        $CatalogHash[$CatalogEntry.id][$CatalogEntry.version] = $CatalogEntry
    }

    $DependencyInfos = New-Object System.Collections.ArrayList

    $TargetFrameworkDependencies = $CatalogEntry.dependencyGroups | Where-Object targetFramework -eq $TargetFramework

    if ($TargetFrameworkDependencies -ne $null -AND (Has-Property $TargetFrameworkDependencies "dependencies")) {
          $TargetFrameworkDependencies | select -expandproperty dependencies | % { $DependencyInfos.Add($_) `
          | Out-Null }
    }

    foreach ($Dependency in $DependencyInfos){

        if (-NOT $CatalogHash.ContainsKey($Dependency.id)) {
            $CatalogHash[$Dependency.id] = @{}
        }

        #determine the version required. may be blank
        $Dependency.range -match '(?<=,\s).*(?=[\]\)])' | Out-Null

        if  ([string]::IsNullOrWhiteSpace($matches[0])){
            $DependencyVersion = -1 #if no end version supplied, get most recent
        } else  {
            $DependencyVersion = $Matches[0]
        }

        if (-NOT $CatalogHash[$Dependency.id].ContainsKey($DependencyVersion)) {

            $DependencyCatalogEntry = Get-CatalogEntry $Dependency.id -Version $DependencyVersion -Log $Log

            $CatalogHash[$Dependency.id][$DependencyVersion] = $DependencyCatalogEntry

            <# Run against the APIs no matter what for now, and then only download if they're missing later? #>
            #if (-NOT $JsonHash.HasLibVersion($Dependency.id, $DependencyCatalogEntry.version) `
            #    -OR $JsonHash.GetLibVersion($Dependency.id, $DependencyCatalogEntry.version).dllPath -eq "missing" `
            #    -OR $JsonHash.GetLibVersion($Dependency.id, $DependencyCatalogEntry.version).xmlPath -eq "missing") {
            #    #Recurse and add 
            #    $CatalogHash = Get-DependenciesOf $DependencyCatalogEntry $JsonHash $CatalogHash
            #}

            $CatalogHash = Get-DependenciesOf $DependencyCatalogEntry $JsonHash $CatalogHash -Log $Log
        }
    }

    return $CatalogHash
}

#download a single dll file and extract it (and the related xml)
function Download-NupkgDll {
[CmdletBinding()]
    param (
        [Parameter(Position=0,
            Mandatory=$true)]
        $PackageDetails,

        [Parameter(Position=2,
            Mandatory=$true)]
        [string]$ZipPathSearchString,

        [Parameter(Position=2,
            Mandatory=$true)]
        [string]$OutPath,

        [Parameter(Position=3)]
        [bool]$Log=$false
    )

    Log ("Downloading Package for {0}" -f $PackageDetails.id) $Log

    $Uri = $PackageDetails.packageInfo.packageContent

    try {
        $WC = New-Object System.Net.WebClient
        
        $Data = $WC.DownloadData($Uri)

        $inputStream = New-Object System.IO.MemoryStream -ArgumentList @(,$Data)

        $ZipArchive = New-Object System.IO.Compression.ZipArchive $inputStream, ([System.IO.Compression.ZipArchiveMode]::Read)

        $Dll = $ZipArchive.Entries | where {$_.FullName -like "lib/$ZipPathSearchString/*" -and `
            ($_.Name -eq ($PackageDetails.id + ".dll") -or $_.Name -eq "_._")}

        if ($Dll -ne $Null) {
            $DllPath = [System.IO.Path]::Combine($OutPath, $Dll.Name)

            $PackageDetails | Add-Member -MemberType NoteProperty -Name "dllPath" -Value $DllPath
            
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Dll, $DllPath)

            $XmlName = $Dll.FullName -replace ".dll",".xml"
        
            $Xml = $ZipArchive.GetEntry($XmlName)

            if ($Xml -ne $Null) {
                $XmlPath = [System.IO.Path]::Combine($OutPath, $Xml.Name)

                $PackageDetails | Add-Member -MemberType NoteProperty -Name "xmlPath" -Value $XmlPath
                if ($XmlName -notlike "*_._") {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Xml, $XmlPath)
                }
            }
        }

    } finally {
        $inputStream.Close()
    }
    
    return $PackageDetails
}

function Get-JsonIndex ($Path, [bool]$Log=$false) {

    Log "Loading or Creating Json Index File" $Log

    $DllPathsJsonPath = [System.IO.Path]::Combine($Path, "LibPaths.json")
    
    if (-not (Test-Path ($DllPathsJsonPath))){
        @{} | ConvertTo-Json | Out-File $DllPathsJsonPath
    }

    $JsonHash = Get-Content $DllPathsJsonPath -Raw | ConvertFrom-Json

    $JsonHash | Add-Member -MemberType NoteProperty -Name "RootPath" -Value $DllPathsJsonPath -Force

    if (-NOT (Has-Property $JsonHash "Libraries")) {
        $JsonHash | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)
    }

    #Save()
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "Save" -Value {
        $this | ConvertTo-Json -Depth 20 | Format-Json | Out-File $this.RootPath -Force
    }

    #HasLib(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "HasLib" -Value {
        param( [string]$LibName)
        return (Has-Property $this.Libraries $LibName)
    }

    #GetLib(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLib" -Value {
        param( [string]$LibName)
        return $this.Libraries.$LibName
    }

    #GetLibAll()
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibAll" -Value {
        return $this.Libraries.psobject.Properties.Name
    }

    #AddLib(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "AddLib" -Value {
        param( [string]$LibName )
        $L = New-Object PSCustomObject
        $L | Add-Member -MemberType NoteProperty -Name "Versions" -Value (New-Object psobject)
        $this.Libraries | Add-Member -NotePropertyName $LibName -NotePropertyValue $L
    }
    
    #HasLibVersion(LibName, Version)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "HasLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return ($this.HasLib($LibName) -and `
            (Has-Property $this.GetLib($LibName).Versions $Version))
    }

    #GetLibVersion(LibName, Version)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return $this.GetLib($LibName).Versions.$Version
    }

    #GetLibVersionAll(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersionAll" -Value {
        param( [string]$LibName)
        return $this.GetLib($LibName).Versions.psobject.Properties.Name
    }

    #AddLibVersion(LibName, Version)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "AddLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        if (-not $This.HasLib($LibName)){
            $this.AddLib($LibName)
        }

        $this.GetLib($LibName).Versions | Add-Member -NotePropertyName $Version -NotePropertyValue `
                    (New-Object PSCustomObject -Property ([ordered]@{
                        "dllPath"=$null
                        "xmlPath"=$null
                        "Dependencies"=@()
                        }))
    }

    #HasLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "HasLibVersionDependency" -Value {
        param([string]$LibName, [string]$Version,
            [string]$DependencyName, [string]$DependencyVersions)

        if ($this.HasLibVersion($LibName, $Version)){
            return (($this.GetLibVersion($LibName, $Version).Dependencies `
                | where {$_.Name -eq $DependencyName -and $_.Version -eq $DependencyVersions}) `
                -ne $null)
        }

    }

    #GetLibVersionDependencies(LibName, Version)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersionDependencies" -Value {
        param([string]$LibName, [string]$Version)

        if ($this.HasLibVersion($LibName, $Version)){
            return $this.GetLibVersion($LibName, $Version).Dependencies
        }
    }

    #AddLibVersionDependency(LibName, Version, DependencyName, DependencyVersion)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "AddLibVersionDependency" -Value {
        param([string]$LibName, [string]$Version,
            [string]$DependencyName, [string]$DependencyVersions)
            if (-not ($this.HasLibVersion($LibName, $Version))) {
                $this.AddLibVersion($LibName, $Version)
            }

            if (-not ($this.HasLibVersionDependency($LibName, $Version,
                $DependencyName, $DependencyVersions))) {

                $D = $this.GetLibVersion($LibName, $Version)
                
                $O = New-Object psobject -Property ([ordered]@{
                    Name = $DependencyName
                    Versions = $DependencyVersions
                })
                
                $D.Dependencies += $O
            }
    }

    #TODO: Add in support for storing dependencies, and then adding that in to checking for missing files!

    #check for missing files and update the json index
    $ChangedInfo = $false

    foreach ($L in $JsonHash.GetLibAll()) {
        foreach ($V in $JsonHash.GetLibVersionAll($L)){
            $Info = $JsonHash.GetLibVersion($L, $V)
            
            if ($Info.dllPath -notlike "*_._" -AND $Info.dllPath -ne $null) {
                if (-NOT (Test-Path $Info.dllPath)){
                    $Info.dllPath = "missing"
                    $ChangedInfo = $true
                }
            }

            if ($Info.xmlPath -notlike "*_._" -AND $Info.xmlPath -ne $null) {
                if (-NOT (Test-Path $Info.xmlPath)){
                    $Info.xmlPath = "missing"
                    $ChangedInfo = $true
                }
            }
        }
    }

    if ($ChangedInfo) {
        $JsonHash.Save()
    }

    return $JsonHash
}

#TODO: Finish this? Make it something to manually run
function Check-JsonLibraryExists ($JsonHash, $DependencyInfo){
    if ($JsonHash.HasLib($DependencyInfo.Name)){
        $Lib = $JsonHash.GetLib($DependencyInfo.Name)
    }

    $DependencyInfo.versions -match '(?<=[\[\(]).*(?=,\s)' | Out-Null

    if (-not  [string]::IsNullOrWhiteSpace($matches[0])){
        $Min = $Matches[0]
    }

    #determine the version required. may be blank
    $DependencyInfo.versions -match '(?<=,\s).*(?=[\]\)])' | Out-Null

    if  (-not [string]::IsNullOrWhiteSpace($matches[0])){
        $Max = $Matches[0]
    }

    $Versions = New-Object System.Collections.ArrayList
    $Lib.Versions.psobject.properties.name | % {$Versions.Add($_)}

    $TargetVersion = $null

    foreach ($V in $Versions) {
      #TODO  
    }

    #if ($JsonHash.HasLibVersion($DependencyInfo.Name, $DependencyInfo.Versions)
}

function Download-Dependencies ($DependencyHash, $OutPath, $JsonHash, [bool]$Log=$false) {

    Log ("Downloading all saved dependencies") $Log

    foreach ($LibKey in $DependencyHash.Keys) {
        
        if (-not $JsonHash.HasLib($LibKey)) {
            $JsonHash.AddLib($LibKey)
        }

        foreach ($VersionKey in $DependencyHash[$LibKey].Keys){

            if (-NOT $JsonHash.HasLibVersion($LibKey, $DependencyHash[$LibKey][-1].version) `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][-1].version).dllPath -eq "missing" `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][-1].version).xmlPath -eq "missing") {

                $PackageDetails = $DependencyHash[$LibKey][$VersionKey]

                $Version = $PackageDetails.version

                $LibOutPath = [System.IO.Path]::Combine($OutPath,$LibKey,$Version)

                if (-not (Test-Path $LibOutPath)) {
                    New-Item -Path $LibOutPath -ItemType "Directory" | Out-Null
                }

                if  (-NOT (test-path ([System.IO.Path]::Combine($LibOutPath,($PackageDetails.id + ".dll"))))) {
                    $PackageDetails = Download-NupkgDll -PackageDetails $PackageDetails -ZipPathSearchString "net45" `
                         -OutPath $LibOutPath -Log $Log
                }

                $Test = $JsonHash.HasLibVersion($LibKey, $Version)

                if (-NOT $JsonHash.HasLibVersion($LibKey, $Version)) {
                    $JsonHash.AddLibVersion($LibKey, $Version)
                }

                if ((Has-Property $PackageDetails "dllPath")) {
                    $JsonHash.GetLibVersion($LibKey, $Version)."dllPath" = $PackageDetails.dllPath
                }
            
                if ((Has-Property $PackageDetails "xmlPath")) {
                    $JsonHash.GetLibVersion($LibKey, $Version)."xmlPath" = $PackageDetails.xmlPath
                }

                $DependencyInfos = New-Object System.Collections.ArrayList

                $TargetFrameworkDependencies = $PackageDetails.dependencyGroups | Where-Object targetFramework -eq $TargetFramework

                if ($TargetFrameworkDependencies -ne $null -AND (Has-Property $TargetFrameworkDependencies "dependencies")) {
                      $TargetFrameworkDependencies | select -expandproperty dependencies | % { 
                        $JsonHash.AddLibVersionDependency($LibKey, $Version, $_.id, $_.range)
                      }
                }

                $JsonHash.Save()
            }
        }
    }
}

function Main ([string]$Package, [bool]$Log=$false) {

    $Root = "$env:USERPROFILE\Desktop\Libraries"

    $NugetIndex = Invoke-RestMethod "https://api.nuget.org/v3/index.json"

    $SearchServiceUri = $NugetIndex.resources[0].'@id'

    #$Package = "Google.Apis.Youtube.v3" #figure out how to extract this from the google discovery API
    $Author = "Google Inc."

    $CatalogEntry = Get-CatalogEntry $Package $Author -IsExactPackageId $true -Log $Log

    $TargetFramework = ".NetFramework4.5"

    $JsonHash = Get-JsonIndex $Root -Log $Log

    $DependencyHash = Get-DependenciesOf $CatalogEntry $JsonHash -Log $Log

    Download-Dependencies $DependencyHash $Root $JsonHash -Log $Log

    return $CatalogEntry
}

<# 
TODO:

1) Figure out how to handle paging of search results
2) Search for all google APIs with proper author
3) For each package, run through Main to d/l items
4) Persist the catalog entry hash throughout each iteration,
     to allow caching of dlls for at least that session
5) Improve logging, fix function formatting and params
#>

Main "Google.Apis.Discovery.v1" -Log $true | Out-Null