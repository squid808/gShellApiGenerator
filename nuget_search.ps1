#TODO: Add System.Management.Automation to the json file!

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

function Get-SearchServiceUri ([bool]$Force=$false) {
    
    if ($global:SearchServiceUri -eq $null -or $Force -eq $true) {

        $NugetIndex = Invoke-RestMethod "https://api.nuget.org/v3/index.json"

        $global:SearchServiceUri = $NugetIndex.resources[0].'@id'
    }

    return $global:SearchServiceUri
}


#run a search against nuget for a package name
function Invoke-NugetApiPackageSearch($PackageName, [string]$Author = $null, [string]$Version = $null, $IsExactPackageId=$false, [bool]$Log=$false) {
    
    $SearchServiceUri = Get-SearchServiceUri

    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $AuthorLog = "by author $Author"
    }

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $VersionLog = " version $Version of"
    }

    Log "Searching for$VersionLog Package $PackageName $AuthorLog" $Log

    if ($IsExactPackageId) {$PackageSpecifier="packageid:"}
    $Uri = ("{0}?q={1}{2}&prerelease=false&includeDelisted=false" -f $SearchServiceUri, $PackageSpecifier, $PackageName)
    
    $results = Invoke-RestMethod $Uri

    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $Data = $results.Data | where {$_.authors.Contains($Author)}
    } else {
        $Data = $results.Data
    }

    if (([string]::IsNullOrWhiteSpace($Version)) -or $Version -eq -1) {
        $Data = $Data | select -ExpandProperty versions | select -Last 1
    } else {
        $Data = $Data | select -ExpandProperty versions | where {$_.version -eq $Version}
    }

    return $Data
}

function Get-CatalogEntry ($SearchResult, [bool]$Log=$false) {

    Log ("Retrieving Catalog Entry for version {0} of {1}" -f $SearchResult.version, $VersionInfo.'@id') $Log

    $VersionPackageInfo = Invoke-RestMethod $SearchResult.'@id'

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

            $DependencyVersionInfo = Get-VersionInfo -PackageName $Dependency.id -Version $DependencyVersion -Log $Log

            $DependencyCatalogEntry = Get-CatalogEntry -VersionInfo $DependencyVersionInfo -Log $Log
            
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

        if ($Dll -eq $null) {
            $Dll = $ZipArchive.Entries | where {$_.FullName -like ("lib/*") -and `
            ($_.Name -eq ($PackageDetails.id + ".dll") -or $_.Name -eq "_._")}
        }

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

    $FoundUpdate = $false

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

                if ($PackageDetails.id -like "*.dll") {
                    $PackageDetails.id = $PackageDetails.id.Replace(".dll","")
                }

                $LibOutPath = [System.IO.Path]::Combine($OutPath,$PackageDetails.id,$Version)

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
                    $PackageDetails.xmlPath = ""
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

                $FoundUpdate = $true
            }
        }
    }

    return $FoundUpdate
}

function Download-PackageFromSearchResult ($LibraryIndex, $SearchResult, $OutPathRoot, $TargetFramework = ".NetFramework4.5", [bool]$Log=$false) {
    
    $CatalogEntry = Get-CatalogEntry -SearchResult $SearchResult -Log $Log

    $DependencyHash = Get-DependenciesOf $CatalogEntry $LibraryIndex -Log $Log

    $FoundChanges = Download-Dependencies $DependencyHash $OutPathRoot $LibraryIndex -Log $Log

    return $CatalogEntry, $FoundChanges
}

function Get-SinglePackageByName ($LibraryIndex, [string]$PackageName, [bool]$Log=$false, [string]$Version = $null, $Author = "Google Inc.") {

    

    Download-PackageFromSearchResult

    $CatalogEntry = Get-CatalogEntry -SearchResult $SearchResult -Log $Log

    $DependencyHash = Get-DependenciesOf $CatalogEntry $LibraryIndex -Log $Log

    $FoundChanges = Download-Dependencies $DependencyHash $LibraryIndexRoot $LibraryIndex -Log $Log

    return $CatalogEntry,$FoundChanges
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

#determine a likely nuget package name based on json info
function Get-NugetPackageIdFromJson ($Json) {
    if ($Json.id -like "admin:*") {
        $PackageId = "{0}.{1}.{2}" -f $Json.name, $Json.canonicalName, $Json.version
    } else {
        $PackageId = ConvertTo-FirstUpper ($Json.id -replace "\.","_" -replace ":",".")
        #$J.id -match "(?=[a-zA-Z])*[^a-zA-Z:\.0-9]" | Out-Null
        #$PackageId = $J.id -replace $matches[0],":" -replace "\.","_" -replace ":","."
    }

    $P = "Google.Apis.$PackageId"

    return $P
}

function Get-ApiPackage ($Name, $Version, [bool]$Log = $false) {
    Log ("Getting the Nuget package for $Name $Version") $Log
    try {
        $Json = Load-RestJsonFile $Name $Version
        $PackageId = (Get-NugetPackageIdFromJson $Json)
        $CatalogEntry,$FoundChanges = Get-SinglePackageByName $PackageId -Log $Log
        return $FoundChanges
    } catch {
        throw $_
    }
}

function Get-AllApiPackages ([bool]$Log = $false) {
    $LibraryIndex = Get-LibraryIndex $LibraryIndexRoot

    foreach ($JsonFileInfo in (gci $JsonRootPath -Recurse -Filter "*.json")){
        $File = Get-MostRecentJsonFile $JsonFileInfo.directory.fullname
        if ($File -ne $null) {
            try {
                $Json = Get-Content $File.FullName | ConvertFrom-Json
                $PackageId = (Get-NugetPackageIdFromJson $Json)
                $CatalogEntry,$FoundChanges = Get-SinglePackageByName $PackageId -Log $Log -LibraryIndex $LibraryIndex
            } catch {
                write-host $_.innerexception.message
            }
        }
    }

    Get-SystemMgmtAuto $LibraryIndex $Log
}

#Start here - do we need 'found changes' now? ~458
# need to set the 'LastVersionBuilt' if downloaded? no, compare 

function Check-AllApiPackages($LibraryIndex, $JsonRootPath, $LibrarySaveFolderPath, [bool]$Log = $false) {
    foreach ($Directory in (gci $JsonRootPath -Directory)){
        $File = Get-MostRecentJsonFile $Directory.fullname

        if ($File -ne $null) {
            try {
                $Json = Get-Content $File.FullName | ConvertFrom-Json
                $PackageId = (Get-NugetPackageIdFromJson $Json)
                $SearchResult = Invoke-NugetApiPackageSearch -PackageName $PackageId -Author "Google Inc." -Version -1 -IsExactPackageId $true -Log $Log
                
                $ShouldDownloadNewest = $false
                
                if ($LibraryIndex.HasLib($PackageId)){
                    $SearchResultVersionObj = [System.Version]$SearchResult.version
                    $LatestVersionObj = [System.Version]$LibraryIndex.GetLibVersionLatestName($PackageId)
                    if ($LatestVersionObj -ne $null -and $LatestVersionObj -lt $SearchResultVersionObj) {
                        $ShouldDownloadNewest = $true
                    }
                } else {
                    $ShouldDownloadNewest = $true
                }

                if ($ShouldDownloadNewest -eq $true) {
                    #START HERE
                    $CatalogEntry,$FoundChanges = Download-PackageFromSearchResult -LibraryIndex $LibraryIndex -SearchResult $SearchResult -OutPathRoot $LibrarySaveFolderPath -Log $Log
                }
            } catch {
                write-host $_.innerexception.message
            }
        }
    }

    Get-SystemMgmtAuto $LibraryIndex $Log
}

function Get-SystemMgmtAuto ($LibraryIndex, [bool]$Log = $false) {
    $SMA = "System.Management.Automation.dll"
    
    if (-not $LibraryIndex.HasLib($SMA)) {
        Get-SinglePackageByName -LibraryIndex $LibraryIndex -PackageName $SMA -Author $null -Log $Log -Version "10.0.10586"
    }
}

#$SearchServiceUri = Get-SearchServiceUri
#
##$Package = "Google.Apis.Youtube.v3" #figure out how to extract this from the google discovery API
#$Author = "Google Inc."
#
#$Package = "Google.Apis.Gmail.v1"
#
#$TargetFramework = ".NetFramework4.5"
#
#$Log = $true
#
#$CatalogEntry = Get-CatalogEntry $Package $Author -IsExactPackageId $true -Log $Log
#
#$JsonHash = Get-LibraryIndex $LibraryIndexRoot -Log $Log
#
#$DependencyHash = Get-DependenciesOf $CatalogEntry $JsonHash -Log $Log
#
#Download-Dependencies $DependencyHash $LibraryIndexRoot $JsonHash -Log $Log

#Get-AllApiPackages -log $true


#Get-SinglePackageByName "Google.Apis" -Log $true

#$VersionInfo = Get-VersionInfo "Google.Apis.Gmail.v1" "Google Inc." -IsExactPackageId $true -Log $Log

#$CatalogEntry = Get-CatalogEntry $VersionInfo -Log $Log

#Get-VersionInfo -PackageName $PackageId -Author $Author -IsExactPackageId $true -Log $Log
Invoke-NugetApiPackageSearch -PackageName $PackageId -Author "Google Inc." -Version -1 -IsExactPackageId $true -Log $Log