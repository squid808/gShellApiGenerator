#TODO: bundle licenses? maybe  add them to the core gshell license page?
#TODO: generate help files
#TODO: handle downloading media content cmdlets
#TODO: Clean up code!
#TODO: allow main invokable to be called with a target path

if ((Get-Command "Invoke-MsBuild") -eq $null) {
    Install-Module -name "Invoke-MsBuild" -Scope CurrentUser -Force
}

$LibraryIndexRoot = "$env:USERPROFILE\Desktop\gShellGen\Libraries"
$RootProjPath = "$env:USERPROFILE\Desktop\gShellGen\GenOutput"
$JsonRootPath = "$env:USERPROFILE\Desktop\gShellGen\DiscoveryRestJson"
$LibraryRepoPath = "$env:USERPROFILE\Documents\GshellAutomationTest"
$WikiRepoPath = "$env:USERPROFILE\Documents\GshellAutomationTest.wiki"
$Log = $true

if (-not (test-path $LibraryIndexRoot)) {New-Item -Path $LibraryIndexRoot -ItemType "directory"}
if (-not (test-path $RootProjPath)) {New-Item -Path $RootProjPath -ItemType "directory"}
if (-not (test-path $JsonRootPath)) {New-Item -Path $JsonRootPath -ItemType "directory"}

#TODO - replace this sometime with proper module structuring, once the project is to that point
function Load-GeneratorFiles {
    dir "$env:USERPROFILE\Documents\gShellApiGenerator" -Filter "*.ps1" | `
        where Name -notlike "main*" | % {. $_.FullName}
}

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

    $BuildUpdates = @{}
    
    if ($ShouldBuildApis -or $ForceBuildApis) {
        #pull out all google apis for which we have an entry in the index
        $ApisFromNuget = $LibraryIndex.Libraries.psobject.Properties.Name | where {$_ -like "Google.Apis*"}
    
        if (-not [string]::IsNullOrWhiteSpace($ApiFilter)) {
            $ApisFromNuget = $ApisFromNuget | where {$_ -like ("Google.Apis." + $ApiFilter)}
        }

        if (($ApisFromNuget.GetType() -like "*Object[[]]*" -and $ApisFromNuget.Count -eq 0) `
            -or ($ApisFromNuget.GetType() -like "*String*" -and [string]::IsNullOrWhiteSpace($ApisFromNuget)))
        {
            Log "No Apis found with the filter `"$ApiFilter`"" $Log
        } else {
            foreach ($ApiName in $ApisFromNuget) {
                
                $LatestDllVersion = $LibraryIndex.GetLibVersionLatestName($ApiName)
                
                $RestNameAndVersion = $LibraryIndex.GetLibRestNameAndVersion($ApiName)

                #TODO: make $JsonRootPath global?
                $JsonFileInfo = Get-MostRecentJsonFile -Path ([System.IO.Path]::Combine($JsonRootPath, $RestNameAndVersion))

                $RestJson = Get-Content $JsonFileInfo.FullName | ConvertFrom-Json

                #TODO: Move API out of here and add it directly to the main program - along with json file bits
                #$BuildResult.Api = Create-TemplatesFromDll -LibraryIndex $LibraryIndex -ApiName $ApiName -ApiFileVersion $LatestDllVersion `
                #    -OutPath $BuildResult.GeneratedProjectPath -RestJson $RestJson -Log $Log

                Log "Loading .dll library in to Api template object" $Log
                $Api = Invoke-GShellReflection -RestJson $RestJson -ApiName $ApiName -ApiFileVersion $LatestDllVersion -LibraryIndex $LibraryIndex

                $BuildResult = CheckAndBuildGShellApi -Api $Api -RootProjPath $RootProjPath -LibraryIndex $LibraryIndex `
                    -Log $Log -Force $ForceBuildApis.IsPresent

                #for successful build
                if ($BuildResult.BuildSucceeded) {
                    $WikiFiles = Write-wiki -Api $Api -ModulePath ([System.IO.Path]::Combine($BuildResult.CompiledDirPath, ($BuildResult.LibName + ".psd1"))) -ModuleVersion $BuildResult.LibVersion -HelpOutDirPath $WikiRepoPath

                    #Use WikiFiles.Count to get the Cmdlets count!
                    $LibraryIndex.SetLibraryVersionCmdletCount($BuildResult.LibName, $BuildResult.LibVersion, $WikiFiles.Count)
                    $LibraryIndex.Save()

                    #TODO: Make this stateless - store in local db?
                    #$BuildUpdates[$GShellApiName] = @{$GShellApiVersion=[System.IO.Path]::GetDirectoryName($CompiledPath)}

                    #TODO: The source code needs to be copied to the repo location for successful generations - can't keep all in one spot to avoid
                    #pushing up bad source code that doesn't build, right?
                } else {
                    #TODO: Update the status on a status wiki page? something like that.
                }


                ##TEST
                ##for now, copy the compiled files to a 'modules' folder
                #$DebugFolder = [System.IO.Path]::GetDirectoryName($CompiledPath)
                #
                #$P = get-content (dir $DebugFolder -Filter "*psd1").FullName
                #
                ##find out the latest alpha version
                #if (($P | ? {$_ -like "*Moduleversion*"} | select -First 1) -match "[0-9]+.[0-9]+.[0-9]+") {
                #    $Matches[0]
                #}
                #
                ##publish this new version with 
                ##TEST
            }
        }
    }

    #if ($BuildUpdates.Keys.Count -gt 0) {
    #    foreach ($ApiKey in $BuildUpdates.Keys) {
    #        foreach ($VersionKey in $BuildUpdates[$ApiKey].Keys) {
    #            Write-host $ApiKey $VersionKey $BuildUpdates[$ApiKey][$VersionKey]
    #        }
    #    }
    #    
    #    #update the wiki and wiki repo here
    #
    #    #update the library repo
    #
    #}
}

#TODO - add in some kind of build summary report at the end - provide error logs for those that didn't work?
Invoke-GshellGeneratorMain -ApiFilter "gmail.v1" -ShouldBuildApis -ForceBuildApis -Log $Log

#Invoke-GshellGeneratorMain -ForceBuildGShell -Log $Log

#Invoke-GshellGeneratorMain -ApiFilter "drive.v3" -ShouldBuildApis -ForceBuildApis -Log $Log

<#
TODO: 
0) make test PoSh repo to get things working, including wiki
1) Figure out how to commit / push to Git via powershell
 options - https://github.com/dahlbyk/posh-git#installing-manual
         - https://stackoverflow.com/questions/28685935/trying-to-commit-to-github-using-powershell-results-in-error-fatal-unable-to-a
2) update a status wiki page with a success / failure (and only commit / push if changes were made)
3) on success, use start-process to run the thing to create wiki pages
    - https://social.technet.microsoft.com/Forums/scriptcenter/en-US/88903837-b9f2-41ea-986c-b66ce8854587/powershell-startprocess-how-to-start-a-powershell-script-with-arguments?forum=ITCG
    - https://github.com/PowerShell/platyPS
4) update wiki index, API page. only commit / push when done and if changed
5) add generated code to repo, push only if any updates
6) push to TEST repo for now.
#>

#$OldPath = $env:PSModulePath
#$Paths = $OldPath -split ";" | where {-not [string]::IsNullOrWhiteSpace($_)}
#$Paths += "C:\Users\svarney\Desktop\gShellGen\GenOutput\gShell.gmail.v1\bin\Debug"
#$env:Path = ($Paths -join ";") + ";"