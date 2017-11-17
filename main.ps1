#TODO: This may not work - what if a json file is updated, but not the nuget file? Do we now make a note of it and check it again every day until it has an update?
#      Maybe resolve this by checking each nuget anyways once a week?

$RootOutPath = "$env:USERPROFILE\Desktop\GenOutput\gShellGmail\"
$LibraryIndexRoot = "$env:USERPROFILE\Desktop\Libraries"

#To Run All Files
function Update-AllFiles ($Log = $false) {

    #First run the discovery API and see what has changed, if anything
    #$DiscoveryChanges = Get-GoogleApiJsonFiles -Log $Log

    #For testing, let's manually create it
    $DiscoveryChanges = @("gmail.v1")

    #Load the Library Index
    $LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log

    #Let's keep track of files from Nuget that were updated
    $NugetChanges = @()

    foreach ($DiscoveryChange in $DiscoveryChanges) {
        Log ("Change found for $DiscoveryChange, checking for related Nuget") $Log
        #Download any updates to this
        #$FoundChanges = Get-ApiPackage $DiscoveryChange -Log $Log
        
        #For Testing, let's pretend we found a change
        $FoundChanges = $true

        if ($FoundChanges -eq $true) {
            
        }
    }

    #CheckAndBuildGshell "C:\Users\svarney\Desktop\GenOutput\gShell" $LibraryIndex -Log $true

}

#Update-AllFiles