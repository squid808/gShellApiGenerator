#TODO: make this path relative from the project itself
$JsonRootPath = "$env:USERPROFILE\Desktop\DiscoveryRestJson"

function Get-GoogleApiList ($Preferred = $false, $Name = $null, [bool]$Log = $false) {
    
    Log ("Getting full list of APIs from Google's Discovery List API.") $Log
    $Uri = "https://www.googleapis.com/discovery/v1/apis?preferred=$Preferred&fields=items(id,name,version,discoveryRestUrl,preferred)"

    if ($Name -ne $null) {$Uri += "&name=$Name"}
    
    $List = Invoke-RestMethod $Uri
    return $List.Items
}

function Get-GoogleRestApi ($Uri, [bool]$RevisionOnly=$false, [bool]$RawContent=$false, [bool]$Log = $false) {
    
    Log ("Getting individual REST API metadata for $Uri") $Log
    if ($RevisionOnly) {
        $Uri += "?fields=version,revision"
    }

    if ($RawContent -eq $true) {
        $Result = (Invoke-WebRequest $Uri).Content
    } else {
        $Result = Invoke-RestMethod $Uri
    }

    return $Result
}

#Check for any changes to the json files themselves from Google, return a list of any that have been updated and downloaded
function Get-GoogleApiJsonFiles ($Name = $null, $Version = $null, $Preferred = $null, [bool]$Log = $false) {
    
    Log ("Checking against Google to determine if any JSON files have a version not found locally.") $Log
    $GoogleApiList = Get-GoogleApiList $Log
    $ChangeResults = New-Object System.Collections.Arraylist

    if ($Name -ne $null) {
        $GoogleApiList = $GoogleApiList | where Name -like $Name
    }

    if ($Version -ne $null) {
        $GoogleApiList = $GoogleApiList | where Version -like $Version
    }

    if ($Preferred -ne $null) {
        $GoogleApiList = $GoogleApiList | where Name -eq $Preferred.ToString()
    }

    #TODO - update this to iterate the whole list
    foreach ($ApiInfo in $GoogleApiList) {

        $Uri = "https://www.googleapis.com/discovery/v1/apis/{0}/{1}/rest" -f $ApiInfo.name, $ApiInfo.version

        $RestRevision = Get-GoogleRestApi $Uri -RevisionOnly $true

        if ($RestRevision.revision -ne $null) {
            $Rev = $RestRevision.revision
        } else {
            $Rev = $RestRevision.version
        }

        $JsonFileFolderName = "{0}.{1}" -f $ApiInfo.name.ToLower(), $ApiInfo.version.ToLower()

        $JsonFileFolder = [System.IO.Path]::Combine($JsonRootPath,$JsonFileFolderName)

        $JsonFileName = "$Rev.json"

        $JsonFilePath = [System.IO.Path]::Combine($JsonFileFolder, $JsonFileName)
        
        #if the file folder doesn't exist, create it
        if (-not (Test-Path $JsonFilePath)) {

            Log ("Downloading $JsonFileName for $JsonFileFolderName") $Log

            if (-not (Test-Path ($JsonFileFolder))) {
                New-Item -Path $JsonFileFolder -ItemType "Directory" | Out-Null
            }

            Get-GoogleRestApi $ApiInfo.discoveryRestUrl -RawContent $true | Out-File -FilePath $JsonFilePath

            $ChangeResults.Add($JsonFileFolderName) | Out-Null
        } else {
            Log ("$JsonFileFolderName / $JsonFileName already exists.") $false #$Log
        }

        $JsonFileFolderName, $JsonFileFolderName, $JsonFileName, $JsonFilePath, $ApiInfo = $null
    }

    return $ChangeResults
}

#Given a folder path, return the most recent json file therein
function Get-MostRecentJsonFile ($Path, [bool]$Log = $false) {
    
    Log ("Finding the most recent Json file in $Path") $Log
    
    $Files = New-Object System.Collections.ArrayList
    
    Get-ChildItem $Path | % {$Files.add($_) | Out-Null}

    if ($Files.Count -eq 1) {
        return $Files[0]
    }

    if ($Files.Count -gt 1) {
        $File = $Files[0]
        $Date = [System.DateTime]::ParseExact(($Files[0].Name -replace ".json",""),"yyyyMMdd",$null)

        for ($i = 1; $i -lt $Files.Count; $i++) {
            $Compare = [System.DateTime]::ParseExact(($Files[$i].Name -replace ".json",""),"yyyyMMdd",$null)

            if ($Compare -gt $Date) { 
                $Date = $Compare
                $File = $Files[$i]
            }
        }

        return $File
    }

    Log ("No Json file found in $Path") $Log
}

#loads the most recent json file path
function Get-JsonApiFile ($Name, $Version, [bool]$Log = $false) {
    $Folder = [System.IO.Path]::Combine($JsonRootPath, ("$Name.$Version"))
    return (Get-MostRecentJsonFile $Folder $Log)
}

#loads the most recent json file
function Load-RestJsonFile ($Name, $Version, [bool]$Log = $false) {
    
    Log ("Loading the most recent Json info for $Name $Version") $Log
    $file = Get-JsonApiFile $Name $Version

    if ($file -ne $null) {
        $Json = Get-Content $file.FullName | ConvertFrom-Json
    }

    return $Json
}