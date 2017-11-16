#To Run All Files
function Update-AllFiles ($Log = $false) {

    #First run the discovery API and see what has changed, if anything
    #$DiscoveryChanges = Get-GoogleApiJsonFiles

    #For testing, let's manually create it
    $DiscoveryChanges = @("gmail.v1")

    foreach ($DiscoveryChange in $DiscoveryChanges) {
        #Download any updates to this
        #$FoundChanges = Get-ApiPackage $DiscoveryChange -Log $Log
        
        #For Testing, let's pretend we found a change
        $FoundChanges = $true

        if($FoundChanges -eq $true) {
            write-host "Found 'em"
        }
    }

}

Update-AllFiles