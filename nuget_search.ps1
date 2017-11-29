#TODO: Add System.Management.Automation to the json file!

add-type -assembly System.IO.Compression
add-type -assembly System.IO.Compression.FileSystem
<#
TODO: Hard-code in versions for APIs for consistency?
#>
function Log ($Message, [bool]$ShouldLog=$false, [string]$ForegroundColor = "Green") {
    if ($ShouldLog) {
        Write-Host $Message -ForegroundColor $ForegroundColor
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
function Invoke-NugetApiPackageSearch {
    
    param  (
        $SearchString,
        
        [string]$Author = $null,

        [bool]$IsExactPackageId = $false,

        [string]$DescriptionSearchString = $null,

        [bool]$Log=$false
    )

    $SearchServiceUri = Get-SearchServiceUri

    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $AuthorLog = "by author $Author"
    }

    Log "Searching for $Package $SearchString $AuthorLog" $Log

    if ($SearchString.Contains(" ")) {
        $SearchString = $SearchString.Replace(" ","+")
    }

    if ($IsExactPackageId) {$PackageSpecifier="packageid:"}
    $Uri = ("{0}?q={1}{2}&prerelease=false&includeDelisted=false" -f $SearchServiceUri, $PackageSpecifier, $SearchString)
    
    $results = Invoke-RestMethod $Uri

    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $Data = $results.Data | where {$_.authors.Contains($Author)}
    } else {
        $Data = $results.Data
    }

    if (-not [string]::IsNullOrWhiteSpace($DescriptionSearchString)) {
        $Data = $Data | where {$_.description.ToLower().Contains($DescriptionSearchString.ToLower())}
    }

    return $Data
}

function Get-SearchResultVersion ($SearchResult, $Version) {
    if (([string]::IsNullOrWhiteSpace($Version)) -or $Version -eq -1) {
        $VersionData = $SearchResult | select -ExpandProperty versions | select -Last 1
    } else {
        $VersionData = $SearchResult | select -ExpandProperty versions | where {$_.version -eq $Version}
    }

    return $VersionData
}

function Get-CatalogEntry ($SearchResultVersionData, [bool]$Log=$false) {

    Log ("Retrieving Catalog Entry for version {0} of {1}" -f $SearchResultVersionData.version, `
        ($SearchResultVersionData.'@id' -split "/" | where {$_ -like "*google*"})) $Log

    $VersionPackageInfo = Invoke-RestMethod $SearchResultVersionData.'@id'

    $CatalogEntry = Invoke-RestMethod $VersionPackageInfo.catalogEntry

    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "packageInfo" -Value $VersionPackageInfo

    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "dllPath" -Value $null
    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "xmlPath" -Value $null
    $CatalogEntry | Add-Member -MemberType NoteProperty -Name "framework" -Value $null

    return $CatalogEntry
}

function Get-LatestVersionFromRange ($VersionRange) {
    
    $matches = $null

    if ($VersionRange -match '(?<=,\s).*(?=[\]\)])' -and -not [string]::IsNullOrWhiteSpace($matches[0])) {
        $Version = $Matches[0]
    } else {
        $version = -1
    }

    return $Version
}

#TODO: Make sure this is only responsible for figuring out the nuget dependencies, which goes hand in hand with downloading them?
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

            #$DependencyVersionInfo = Get-VersionInfo -PackageName $Dependency.id -Version $DependencyVersion -Log $Log

            $SearchResult = Invoke-NugetApiPackageSearch -SearchString $Dependency.id `
                -IsExactPackageId $true -Log $Log

            $VersionData = Get-SearchResultVersion $SearchResult -Version $DependencyVersion

            $DependencyCatalogEntry = Get-CatalogEntry -SearchResultVersionData $VersionData -Log $Log
            
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

function Download-Dependencies ($DependencyHash, $OutPath, $JsonHash, [bool]$Log=$false, [bool]$Force=$false) {

    Log ("Downloading all saved dependencies") $Log

    $FoundUpdate = $false

    foreach ($LibKey in $DependencyHash.Keys) {
        
        if (-not $JsonHash.HasLib($LibKey)) {
            $JsonHash.AddLib($LibKey)
        }

        foreach ($VersionKey in ($DependencyHash[$LibKey].Keys| where {$_ -ne -1})){
            
            $PackageDetails = $DependencyHash[$LibKey][$VersionKey]

            if (-NOT $JsonHash.HasLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version) `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).dllPath -eq "missing" `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).dllPath -eq $null `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).xmlPath -eq "missing" `
                -OR $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).xmlPath -eq $null `
                -OR $Force -eq $true) {

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
            } else {
                $PackageDetails.dllPath = $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).dllPath
                $PackageDetails.xmlPath = $JsonHash.GetLibVersion($LibKey, $DependencyHash[$LibKey][$VersionKey].version).xmlPath
            }
        }
    }

    return $FoundUpdate
}

function Download-PackageFromSearchResult ($LibraryIndex, $VersionData, $OutPathRoot, $TargetFramework = ".NetFramework4.5", [bool]$Log=$false, [bool]$Force=$false) {
    
    $CatalogEntry = Get-CatalogEntry -SearchResultVersionData $VersionData -Log $Log

    $DependencyHash = Get-DependenciesOf $CatalogEntry $LibraryIndex -Log $Log

    $FoundChanges = Download-Dependencies $DependencyHash $OutPathRoot $LibraryIndex -Log $Log -Force $Force

    return $CatalogEntry, $FoundChanges
}

function Get-SinglePackageByName ($LibraryIndex, [string]$PackageName, [string]$Version = $null, $OutPathRoot, $TargetFramework = ".NetFramework4.5",
        $Author = "Google Inc.", [bool]$Log=$false,  [bool]$Force=$false) {

    $SearchResult = Invoke-NugetApiPackageSearch -SearchString $PackageName -Author $Author -IsExactPackageId $true -Log $Log

    $VersionData = Get-SearchResultVersion -SearchResult $SearchResult

    return (Download-PackageFromSearchResult -LibraryIndex $LibraryIndex -VersionData $VersionData -OutPathRoot $OutPathRoot -TargetFramework $TargetFramework `
        -Log $Log -Force $Force)

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

$NugetPackageAlternateIds = @{
    "Google.Apis.Adexchangebuyer2.v2beta1" = "Google.Apis.AdexchangebuyerII.v2beta1"
    "Google.Apis.Androiddeviceprovisioning.v1" = "Google.Apis.AndroidProvisioningPartner.v1"
    "Google.Apis.Content.v2sandbox" = "Google.Apis.ShoppingContent.v2sandbox"
    "Google.Apis.Deploymentmanager.alpha" = "Google.Apis.DeploymentManagerAlpha.alpha"
    "Google.Apis.Deploymentmanager.v2beta" = "Google.Apis.DeploymentManagerV2Beta.v2beta"
    "Google.Apis.Dialogflow.v2beta1" = ""
    "Google.Apis.Firestore.v1beta1" = ""
    "Google.Apis.Language.v1" = ""
    "Google.Apis.Language.v1beta1" = ""
    "Google.Apis.Language.v1beta2" = ""
    "Google.Apis.Manufacturers.v1" = ""
    "Google.Apis.Ml.v1" = ""
    "Google.Apis.Oslogin.v1alpha" = ""
    "Google.Apis.Oslogin.v1beta" = ""
    "Google.Apis.Runtimeconfig.v1" = ""
    "Google.Apis.Sourcerepo.v1" = ""
    "Google.Apis.Videointelligence.v1beta1" = ""

}

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

    #if ($NugetPackageAlternateIds.ContainsKey($P)) {
    #    $P = $NugetPackageAlternateIds[$P]
    #}

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

#a three-pronged approach to searching for Google API packages when searching for the first time, returns a new package ID if the default isn't found.
function Invoke-BroadGoogleSearchOnNuget ($PackageId, $Json, [bool]$Log = $false){
    Log "Attempting to find $PackageId through a direct search" $Log
    $SearchResult = Invoke-NugetApiPackageSearch -SearchString $PackageId -Author "Google Inc." -Version -1 -IsExactPackageId $true -Log $Log
    
    if ($SearchResult -eq $null) {
        if (-not [string]::IsNullOrWhiteSpace($json.CanonicalName)) {
            $PackageId = "Google.Apis." + $Json.canonicalName.Replace(" ","") + "." + $json.version
            Log "No results. Attempting to find $PackageId through a direct search" $Log
            $SearchResult = Invoke-NugetApiPackageSearch -SearchString $PackageId -Author "Google Inc." -Version -1 -IsExactPackageId $true -Log $Log
        }
    }

    if ($SearchResult -eq $null) {
        Log ("No results. Attempting to find {0} {1} through a broad search via descriptions" -f $Json.Name, $Json.Version) $Log
        $DescriptionSearch = "Google APIs Client Library for working with {0} {1}." -f $Json.Name, $Json.Version
        $SearchResult = Invoke-NugetApiPackageSearch -SearchString ("Google {0} {1}" -f $Json.Name, $Json.Version) `
            -Author "Google Inc." -IsExactPackageId $false -DescriptionSearchString $DescriptionSearch
    }

    return $SearchResult
}

function Check-AllApiPackages($LibraryIndex, $JsonRootPath, $LibrarySaveFolderPath, [string]$Filter=$null, [bool]$Log = $false) {
    foreach ($Directory in (gci $JsonRootPath -Directory -Filter $filter)){
        Log "" $Log
        $File = Get-MostRecentJsonFile $Directory.fullname

        if ($File -ne $null) {
            $Json = Try-ConvertFromJson $File.FullName -Log $Log
            $PackageId = (Get-NugetPackageIdFromJson $Json)
                
            $ShouldDownloadNewest = $false

            $NameRedirect = $LibraryIndex.GetLibNameRedirect($PackageId)

            if (-not [string]::IsNullOrWhiteSpace($NameRedirect)) {
                Log ("Redirecting to $NameRedirect") $Log
                $PackageId = $NameRedirect
            }
                
            if ($LibraryIndex.HasLib($PackageId)){
                $SearchResult = Invoke-NugetApiPackageSearch -SearchString $PackageId -Author "Google Inc." -IsExactPackageId $true -Log $Log
                $VersionData = Get-SearchResultVersion -SearchResult $SearchResult -Version -1
                $VersionDataObj = [System.Version]$VersionData.version
                $LatestVersion = $LibraryIndex.GetLibVersionLatestName($PackageId)
                $LatestVersionObj = [System.Version]$LatestVersion
                if ($LatestVersionObj -ne $null -and $LatestVersionObj -lt $VersionDataObj) {
                    $ShouldDownloadNewest = $true
                    Log ("({0} => {1}) Old version of $PackageId found locally." -f $VersionData.version, $LatestVersion) $Log
                } else {
                    Log ("$PackageId is up to date.") $Log
                }
            } else {
                #since this is the first time we've encountered it, let's run a big search to make sure we can find it
                $SearchResult = Invoke-BroadGoogleSearchOnNuget -PackageId $PackageId -Json $Json -Log $True
                $VersionData = Get-SearchResultVersion -SearchResult $SearchResult -Version -1
                $LibraryIndex.SetLibRestNameAndVersion($PackageId, $Directory.Name)

                if ($SearchResult.id -ne $PackageId) {
                    Log ("Adding name redirect of {0} => {1}" -f $PackageId, $SearchResult.id) $Log
                    $LibraryIndex.SetLibNameRedirect($PackageId, $SearchResult.id)
                    $LibraryIndex.SetLibRestNameAndVersion($SearchResult.id, $Directory.Name)
                    $PackageId = $SearchResult.id
                }

                $LibraryIndex.Save()

                $ShouldDownloadNewest = $true
                Log ("$PackageId is not found in the library index.") $Log
            }

            #download the newest version
            if ($ShouldDownloadNewest -eq $true) {
                if ($SearchResult -ne $null) {
                    $CatalogEntry, $FoundChanges = Download-PackageFromSearchResult -LibraryIndex $LibraryIndex -VersionData $VersionData `
                        -OutPathRoot $LibraryIndexRoot -TargetFramework ".NetFramework4.5" -Log $Log
                } else {
                    Log ("No nuget results found for $PackageId.") $Log
                    Write-Host $PackageId -ForegroundColor Red
                }
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


#Get-NugetPackageIdFromJson $Json

#$LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log
#