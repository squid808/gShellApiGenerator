add-type -assembly System.IO.Compression
add-type -assembly System.IO.Compression.FileSystem
<#
TODO: Hard-code in versions for APIs for consistency?
#>
function Log ($Message, [bool]$ShouldLog=$false) {
    if ($ShouldLog) {
        Write-Host $Message -ForegroundColor Green
    }
}

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
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

function SearchForNugetPackage($SearchServiceUri, $Package, $IsExactPackageId=$false, [bool]$Log=$false){
    
    Log "Searching for Package $Package" $Log

    if ($IsExactPackageId) {$PackageSpecifier="packageid:"}
    $Uri = ("{0}?q={1}{2}&prerelease=false&includeDelisted=false" -f $SearchServiceUri, $PackageSpecifier, $Package)
    
    $results = Invoke-RestMethod $Uri

    return $results
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

    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "dllPath" -Value $null
    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "xmlPath" -Value $null
    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "framework" -Value $null

    return $CatalogEntry
}

function Get-LatestVersionFromRange ($VersionRange) {
    
    $matches = $null

    $VersionRange -match '(?<=,\s).*(?=[\]\)])' | Out-Null

    if  ([string]::IsNullOrWhiteSpace($matches[0])){
        $Version = -1 #if no end version supplied, get most recent
    } else  {
        $Version = $Matches[0]
    }

    return $Version
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
        #actual versions here
        $CatalogHash[$CatalogEntry.id][$CatalogEntry.version] = $CatalogEntry
    }

    $DependencyInfos = New-Object System.Collections.ArrayList

    if ($CatalogEntry.dependencyGroups.Count -eq 1 -and -not (Has-ObjProperty $CatalogEntry.dependencyGroups "targetFramework")){
        #in the less often cases where there is only one dependency that has no target framework
        $TargetFrameworkDependencies = $CatalogEntry.dependencyGroups[0]
    } else {
        $TargetFrameworkDependencies = $CatalogEntry.dependencyGroups | Where-Object targetFramework -eq $TargetFramework
        $CatalogEntry.framework = $TargetFramework
    }

    if ($TargetFrameworkDependencies -ne $null -AND (Has-objProperty $TargetFrameworkDependencies "dependencies")) {
          $TargetFrameworkDependencies | select -expandproperty dependencies | % { $DependencyInfos.Add($_) `
          | Out-Null }
    }

    foreach ($Dependency in $DependencyInfos){

        if (-NOT $CatalogHash.ContainsKey($Dependency.id)) {
            $CatalogHash[$Dependency.id] = @{}
        }
        
        $DependencyVersion = Get-LatestVersionFromRange $Dependency.Range

        if (-NOT $CatalogHash[$Dependency.id].ContainsKey($DependencyVersion)) {

            $DependencyCatalogEntry = Get-CatalogEntry $Dependency.id -Version $DependencyVersion -Log $Log
            
            # save both -1 and the actual version - the -1 is to let us know not to do it again, the version is for later
            $CatalogHash[$Dependency.id][$DependencyVersion] = $DependencyCatalogEntry
            #$CatalogHash[$Dependency.id][$DependencyCatalogEntry.version] = $DependencyCatalogEntry

            <# Run against the APIs no matter what for now, and then only download if they're missing later? #>
            #if (-NOT $JsonHash.HasLibVersion($Dependency.id, $DependencyCatalogEntry.version) `
            #    -OR $JsonHash.GetLibVersion($Dependency.id, $DependencyCatalogEntry.version).dllPath -eq "missing" `
            #    -OR $JsonHash.GetLibVersion($Dependency.id, $DependencyCatalogEntry.version).xmlPath -eq "missing") {
            #    #Recurse and add 
            #    $CatalogHash = Get-DependenciesOf $DependencyCatalogEntry $JsonHash $CatalogHash
            #}

            $CatalogHash = Get-DependenciesOf $DependencyCatalogEntry $JsonHash $CatalogHash -Log $Log
        } else {
            Log ("The CatalogHash already contains info for {0} version {1}" -f $Dependency.id, $DependencyVersion) $Log
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

        [Parameter(Position=1,
            Mandatory=$true)]
        [string]$OutPath,

        [Parameter(Position=2)]
        [bool]$Log=$false
    )

    Log ("Downloading Package for {0}" -f $PackageDetails.id) $Log

    $Uri = $PackageDetails.packageInfo.packageContent

    try {
        $WC = New-Object System.Net.WebClient
        
        $Data = $WC.DownloadData($Uri)

        $inputStream = New-Object System.IO.MemoryStream -ArgumentList @(,$Data)

        $ZipArchive = New-Object System.IO.Compression.ZipArchive $inputStream, ([System.IO.Compression.ZipArchiveMode]::Read)

        if ($PackageDetails.framework -eq ".NetFramework4.5") {
            $ZipPathSearchString = "/net45"
        }

        $Dll = $ZipArchive.Entries | where {$_.FullName -like ("lib" + $ZipPathSearchString + "/*") -and `
            ($_.Name -eq ($PackageDetails.id + ".dll") -or $_.Name -eq "_._")}

        if ($Dll -ne $Null) {
            $DllPath = [System.IO.Path]::Combine($OutPath, $Dll.Name)

            $PackageDetails.dllPath = $DllPath
            
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Dll, $DllPath)

            $XmlName = $Dll.FullName -replace ".dll",".xml"
        
            $Xml = $ZipArchive.GetEntry($XmlName)

            if ($Xml -ne $Null) {
                $XmlPath = [System.IO.Path]::Combine($OutPath, $Xml.Name)

                $PackageDetails.xmlPath = $XmlPath
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

    if (-NOT (Has-ObjProperty $JsonHash "Libraries")) {
        $JsonHash | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)
    }

    #Save()
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "Save" -Value {
        $this | ConvertTo-Json -Depth 20 | Format-Json | Out-File $this.RootPath -Force
    }

    #HasLib(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "HasLib" -Value {
        param( [string]$LibName)
        return (Has-ObjProperty $this.Libraries $LibName)
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
            (Has-ObjProperty $this.GetLib($LibName).Versions $Version))
    }

    #GetLibVersion(LibName, Version)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersion" -Value {
        param( [string]$LibName, [string]$Version)
        return $this.GetLib($LibName).Versions.$Version
    }

    #GetLibVersionAll(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersionAll" -Value {
        param( [string]$LibName)
        return $this.GetLib($LibName).Versions.psobject.Properties
    }

    #GetLibVersionLatest(LibName)
    $JsonHash | Add-Member -MemberType ScriptMethod -Name "GetLibVersionLatest" -Value {
        param( [string]$LibName)
        $version = $this.GetLibVersionAll($LibName).name | sort -Descending | select -First 1
        if ($version -ne $null) {
            $result = $this.GetLibVersion($LibName, $Version)
        }
        return $result
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
        foreach ($V in $JsonHash.GetLibVersionAll($L).Name){
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

        foreach ($VersionKey in ($DependencyHash[$LibKey].Keys| where {$_ -ne -1})){
            
            if (-NOT $JsonHash.HasLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version) `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).dllPath -eq "missing" `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).dllPath -eq $null `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).xmlPath -eq "missing" `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).xmlPath -eq $null) {

                $PackageDetails = $DependencyHash[$LibKey][$VersionKey]

                $Version = $PackageDetails.version

                $LibOutPath = [System.IO.Path]::Combine($OutPath,$LibKey,$Version)

                if (-not (Test-Path $LibOutPath)) {
                    New-Item -Path $LibOutPath -ItemType "Directory" | Out-Null
                }

                $Path = [System.IO.Path]::Combine($LibOutPath,$PackageDetails.id)

                #check if the files already exist on disk, just in case the index file is screwed up
                if  (-NOT (test-path ($Path + ".dll")) -and -NOT (test-path ([System.IO.Path]::Combine($LibOutPath,"_._")))) {
                    $PackageDetails = Download-NupkgDll -PackageDetails $PackageDetails `
                         -OutPath $LibOutPath -Log $Log
                } elseif ((test-path ([System.IO.Path]::Combine($LibOutPath,"_._")))) {
                    #the files exist as _._
                    $PackageDetails.dllPath = [System.IO.Path]::Combine($LibOutPath,"_._")
                    $PackageDetails.xmlPath = $null
                } else {
                    #for some reason the file exists but isn't in the json file
                    $PackageDetails.dllPath = $Path + ".dll"

                    if (test-path ($Path + ".xml")) {
                        $PackageDetails.xmlPath = $Path + ".xml"
                    }
                }

                $Test = $JsonHash.HasLibVersion($LibKey, $Version)

                if (-NOT $JsonHash.HasLibVersion($LibKey, $Version)) {
                    $JsonHash.AddLibVersion($LibKey, $Version)
                }

                if ((Has-ObjProperty $PackageDetails "dllPath")) {
                    $JsonHash.GetLibVersion($LibKey, $Version)."dllPath" = $PackageDetails.dllPath
                }
            
                if ((Has-ObjProperty $PackageDetails "xmlPath")) {
                    $JsonHash.GetLibVersion($LibKey, $Version)."xmlPath" = $PackageDetails.xmlPath
                }

                $DependencyInfos = New-Object System.Collections.ArrayList

                $TargetFrameworkDependencies = $PackageDetails.dependencyGroups | Where-Object targetFramework -eq $TargetFramework

                if ($TargetFrameworkDependencies -ne $null -AND (Has-ObjProperty $TargetFrameworkDependencies "dependencies")) {
                      $TargetFrameworkDependencies | select -expandproperty dependencies | % { 
                        $JsonHash.AddLibVersionDependency($LibKey, $Version, $_.id, $_.range)
                      }
                }

                $JsonHash.Save()
            }
        }
    }
}

function Get-SearchServiceUri ([bool]$Force=$false) {
    
    if ($global:SearchServiceUri -eq $null -or $Force -eq $true) {

        $NugetIndex = Invoke-RestMethod "https://api.nuget.org/v3/index.json"

        $global:SearchServiceUri = $NugetIndex.resources[0].'@id'
    }

    return $global:SearchServiceUri
}

function Get-SinglePackageByName ([string]$Package, [bool]$Log=$false) {

    $SearchServiceUri = Get-SearchServiceUri

    #$Package = "Google.Apis.Youtube.v3" #figure out how to extract this from the google discovery API
    $Author = "Google Inc."

    $CatalogEntry = Get-CatalogEntry $Package $Author -IsExactPackageId $true -Log $Log

    $TargetFramework = ".NetFramework4.5"

    $JsonHash = Get-JsonIndex $LibraryIndexRoot -Log $Log

    $DependencyHash = Get-DependenciesOf $CatalogEntry $JsonHash -Log $Log

    Download-Dependencies $DependencyHash $LibraryIndexRoot $JsonHash -Log $Log

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

#Get-SinglePackageByName "Google.Apis.Admin.Directory_v1" -Log $true | Out-Null

#determine a likely nuget package name based on json info
function Get-NugetPackageIdFromJson ($Json) {
    if ($Json.id -like "admin:*") {
        $PackageId = "{0}.{1}.{2}" -f $Json.name, $Json.canonicalName, $Json.version
    } else {
        $PackageId = $Json.id -replace "\.","_" -replace ":","."
        #$J.id -match "(?=[a-zA-Z])*[^a-zA-Z:\.0-9]" | Out-Null
        #$PackageId = $J.id -replace $matches[0],":" -replace "\.","_" -replace ":","."
    }

    $P = "Google.Apis.$PackageId"

    return $P
}

function Get-ApiPackage ($Name, $Version) {
    try {
        $Json = Load-RestJsonFile $Name $Version
        $PackageId = (Get-NugetPackageIdFromJson $Json)
        $CatalogEntry = Get-SinglePackageByName $PackageId -Log $true
    } catch {
        throw $_
    }
}

function Get-AllApiPackages {
    foreach ($JsonFileInfo in (gci $JsonRootPath -Recurse -Filter "*.json")){
        $File = Get-MostRecentJsonFile $JsonFileInfo.directory.fullname
        if ($File -ne $null) {
            try {
                $Json = Get-Content $File.FullName | ConvertFrom-Json
                $PackageId = (Get-NugetPackageIdFromJson $Json)
                $CatalogEntry = Get-SinglePackageByName $PackageId -Log $true
            } catch {
                write-host $_.innerexception.message
            }
        }
    }
}

$LibraryIndexRoot = "$env:USERPROFILE\Desktop\Libraries"

$SearchServiceUri = Get-SearchServiceUri

#$Package = "Google.Apis.Youtube.v3" #figure out how to extract this from the google discovery API
$Author = "Google Inc."

$Package = "Google.Apis.Gmail.v1"

$TargetFramework = ".NetFramework4.5"

$Log = $true

$CatalogEntry = Get-CatalogEntry $Package $Author -IsExactPackageId $true -Log $Log

$JsonHash = Get-JsonIndex $LibraryIndexRoot -Log $Log

$DependencyHash = Get-DependenciesOf $CatalogEntry $JsonHash -Log $Log

Download-Dependencies $DependencyHash $LibraryIndexRoot $JsonHash -Log $Log