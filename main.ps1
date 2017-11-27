#TODO: This may not work - what if a json file is updated, but not the nuget file? Do we now make a note of it and check it again every day until it has an update?
#      Maybe resolve this by checking each nuget anyways once a week?

$LibraryIndexRoot = "$env:USERPROFILE\Desktop\Libraries"
$RootProjPath = "$env:USERPROFILE\Desktop\GenOutput"
$JsonRootPath = "$env:USERPROFILE\Desktop\DiscoveryRestJson"
$Log = $true

#To Run All Files
function Update-AllFiles ($Log = $false) {

    #First run the discovery API and see what has changed, if anything
    #$DiscoveryChanges = Get-GoogleApiJsonFiles -Log $Log

    #For testing, let's manually create it
    $DiscoveryChanges = @("gmail.v1")

    #Load the Library Index
    $LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log
    
    #Now that all the json files are up to date (right?) let's see if the nuget files are too
    #Check-AllApiPackages -LibraryIndex $LibraryIndex -JsonRootPath $JsonRootPath `
    #    -LibrarySaveFolderPath $LibraryIndexRoot -Log $log

    #START HERE - why is this breaking now
    #CheckAndBuildGshell ([System.IO.Path]::Combine($rootProjPath,"gShell")) $LibraryIndex -Log $true
    
    #pull out all google apis for which we have an entry in the index
    #$ApisFromNuget = $LibraryIndex.Libraries.psobject.Properties.Name | where {$_ -like "Google.Apis*"}
    
    #TESTING:
    $ApiName = "Google.Apis.Gmail.v1"

    

    #foreach ($ApiName in $ApisFromNuget) {
        
    #}
}



#Update-AllFiles

