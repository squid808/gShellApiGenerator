#TODO: bundle licenses? maybe  add them to the core gshell license page?
#TODO: generate help files
#TODO: handle downloading media content cmdlets
#TODO: Clean up code!
#TODO: allow main invokable to be called with a target path

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
                $GShellApiName,$GShellApiVersion,$CompiledPath = CheckAndBuildGShellApi -ApiName $ApiName -RootProjPath $RootProjPath -LibraryIndex $LibraryIndex `
                    -Log $Log -Force $ForceBuildApis.IsPresent

                #TEST
                #for now, copy the compiled files to a 'modules' folder
                $DebugFolder = [System.IO.Path]::GetDirectoryName($CompiledPath)

                $P = get-content (dir $DebugFolder -Filter "*psd1").FullName

                #find out the latest alpha version
                if (($P | ? {$_ -like "*Moduleversion*"} | select -First 1) -match "[0-9]+.[0-9]+.[0-9]+") {
                    $Matches[0]
                }

                #publish this new version with 
                #TEST
            }
        }
    }
}

#TODO - add in some kind of build summary report at the end - provide error logs for those that didn't work?
#Invoke-GshellGeneratorMain -ApiFilter "gmail.v1" -ShouldBuildApis -ForceBuildApis -Log $Log

#Invoke-GshellGeneratorMain -ForceBuildGShell -Log $Log

Invoke-GshellGeneratorMain -ApiFilter "drive.v3" -ShouldBuildApis -ForceBuildApis -Log $Log