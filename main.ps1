#TODO: This may not work - what if a json file is updated, but not the nuget file? Do we now make a note of it and check it again every day until it has an update?
#      Maybe resolve this by checking each nuget anyways once a week?

$LibraryIndexRoot = "$env:USERPROFILE\Desktop\Libraries"
$RootProjPath = "$env:USERPROFILE\Desktop\GenOutput"
$JsonRootPath = "$env:USERPROFILE\Desktop\DiscoveryRestJson"
$Log = $true

#To Run All Files
function Invoke-GshellGeneratorMain {

    param (
        [string]$ApiFilter,
        [switch]$ShouldCheckDiscovery,
        [switch]$ShouldCheckNuget,
        [switch]$ShouldBuildGShell,
        [switch]$ForceBuildGShell,
        [switch]$ShouldBuildApis,
        [switch]$ForceBuildApis,
        [bool]$Log = $False
    )

    #Load the Library Index
    $LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log

    if ($ShouldCheckDiscovery) {
        #First run the discovery API and see what has changed, if anything
        $DiscoveryChanges = Get-GoogleApiJsonFiles -Log $Log -Filter $ApiFilter
    }
    
    if ($ShouldCheckNuget) {
        #Now that all the json files are up to date (right?) let's see if the nuget files are too
        Check-AllApiPackages -LibraryIndex $LibraryIndex -JsonRootPath $JsonRootPath `
            -LibrarySaveFolderPath $LibraryIndexRoot -Filter $ApiFilter -Log $log
    }

    if ($ShouldBuildGShell -or $ForceBuildGShell) {

        $GShellName,$GShellVersion = CheckAndBuildGshell ([System.IO.Path]::Combine($rootProjPath,"gShell.Main")) -LibraryIndex $LibraryIndex `
            -Log $Log -Force $ForceBuildGShell.IsPresent
    }
    
    if ($ShouldBuildApis -or $ForceBuildApis) {
        #pull out all google apis for which we have an entry in the index
        $ApisFromNuget = $LibraryIndex.Libraries.psobject.Properties.Name | where {$_ -like "Google.Apis*"}
    
        if (-not [string]::IsNullOrWhiteSpace($ApiFilter)) {
            $ApisFromNuget = $ApisFromNuget | where {$_ -like ("Google.Apis." + $ApiFilter)}
        }

        if ($ApisFromNuget.Count -eq 0) {
            Log "No Apis found with the filter `"$ApiFilter`"" $Log
        } else {
            foreach ($ApiName in $ApisFromNuget) {
                Log "" $Log
                $GShellApiName,$GShellApiVersion = CheckAndBuildGShellApi -ApiName $ApiName -RootProjPath $RootProjPath -LibraryIndex $LibraryIndex `
                    -Log $Log -Force $ForceBuildApis.IsPresent
            }
        }
    }
}

Invoke-GshellGeneratorMain -ApiFilter "genomics.v1alpha2" -ShouldBuildApis -ForceBuildApis -Log $Log

