#TODO: make this path relative from the project itself


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
function Get-GoogleApiJsonFiles ($Name = $null, $Version = $null, $Preferred = $null, $Filter = $null, [bool]$Log = $false) {
    
    Log ("Checking against Google to determine if any JSON files have a version not found locally.") $Log
    $GoogleApiList = Get-GoogleApiList $Log
    $ChangeResults = New-Object System.Collections.Arraylist

    if (-not [string]::IsNullOrWhiteSpace($Filter)) {
        $GoogleApiList = $GoogleApiList | where Id -like $Filter
    }

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $GoogleApiList = $GoogleApiList | where Name -like $Name
    }

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $GoogleApiList = $GoogleApiList | where Version -like $Version
    }

    if ($Preferred -eq $true) {
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
            Log ("$JsonFileFolderName / $JsonFileName already exists.") $Log
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

#Start parsing json that contains duplicate keys
function Parse-JsonForDups ($Json, [bool]$Log=$false, [bool]$Debug=$false) {
    $Lines = $Json -split "`r`n"

    $Parsed = Parse-JsonForDupsInner ([ref]$Lines) -Log $Log -Debug $Debug

    return ($Lines -join "`r`n")
}

#the inner recursive function to parse json duplicate keys, do not use except within parse-jsonfordups
function Parse-JsonForDupsInner ([ref]$LinesRef, [int]$Start = 0, $AsList = $false, [int]$Level = 0, [bool]$Log=$false, [bool]$Debug=$false) {
    $Keys = New-Object 'System.Collections.Generic.HashSet[string]'

    for ($i = $Start;  $i -lt $Lines.Count; $i++) {
        Log ("Level $Level, $i " + $Lines[$i]) $Debug

        if ($AsList -eq $false -and $LinesRef.Value[$i] -match '\s*"\w+"\s*:.*') {
            $Key = $Matches[0] -split '"' | where {-not [string]::IsNullOrWhiteSpace($_)} | select -First 1
            
            $Padding = 0

            Log $key $Debug -ForegroundColor Cyan
            
            if ($Keys.Contains($Key.ToLower())) {
                $OriginalKey = $Key

                while ($Keys.Contains($Key.ToLower()) ) {
                    Log "$Key exists, padding +1" $Debug
                    $Padding++

                    $Key = $OriginalKey + ("_"*$Padding)
                }

                $LinesRef.Value[$i] = $LinesRef.Value[$i].Replace($OriginalKey,$Key)
                Log "Replacing $OriginalKey with $Key" $true -ForegroundColor Red
            }

            

            Log "Adding $Key to the hash" $Debug -ForegroundColor DarkYellow
            $Keys.Add($Key.ToLower()) | Out-Null
        }

        if ($LinesRef.Value[$i] -like '*{') {
            Log "This is an opening bracket, recursing" $Debug -ForegroundColor "DarkRed"
            $i = Parse-JsonForDupsInner ([ref]$LinesRef.Value) -Start ($i+1) -Level ($Level + 1) -Log $Log -Debug $Debug #return the last line checked already
        } elseif ($LinesRef.Value[$i] -like '*[\[]') {
            Log "This is an opening bracket, recursing as list" $Debug -ForegroundColor "DarkRed"
            $i = Parse-JsonForDupsInner ([ref]$LinesRef.Value) -Start ($i+1) -Level ($Level + 1) -Log $Log -Debug $Debug -AsList $true
        } elseif ($LinesRef.Value[$i] -match '[\]}][,]*$') {
            Log "Found closing bracket. Backing out." $Debug -ForegroundColor "DarkRed"
            return $i
        }
    }
}

function Try-ConvertFromJson ($JsonPath, [bool]$Log=$false, [bool]$Debug=$false) {
    $Content = Get-Content $JsonPath
    
    try {
        $Json = ($Content | ConvertFrom-Json)
        return $json
    } catch {
        if ($_.Exception.Message.Contains("duplicated keys")) {
            Log "Json couldn't be loaded due to duplicate keys. Attempting to sanitize, this may take a few minutes..." $Log
            $NoDupsContent = Parse-JsonForDups $Content $Log $Debug
            $Json = $NoDupsContent | ConvertFrom-Json
            $NoDupsContent | Out-File $JsonPath -Force
            Log "...sanitizing keys successful. File updated." $Log
        } else {
            throw $_
        }
    }

    return $Json
}