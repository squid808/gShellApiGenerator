#TODO: This may not work - what if a json file is updated, but not the nuget file? Do we now make a note of it and check it again every day until it has an update?
#      Maybe resolve this by checking each nuget anyways once a week?

$RootOutPath = "$env:USERPROFILE\Desktop\GenOutput\gShellGmail\"
$LibraryIndexRoot = "$env:USERPROFILE\Desktop\Libraries"
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
    CheckAndBuildGshell "C:\Users\svarney\Desktop\GenOutput\gShell" $LibraryIndex -Log $true
    #$LibraryIndex.Libraries.psobject.Properties.Name | where {$_ -like "Google.Apis*"}
}

Update-AllFiles