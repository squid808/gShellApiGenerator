$JsonRootPath = "$env:USERPROFILE\Desktop\DiscoveryRestJson"

function Get-GoogleApiList ($Preferred = $false, $Name = $null) {
    $Uri = "https://www.googleapis.com/discovery/v1/apis?preferred=$Preferred&fields=items(id,name,version,discoveryRestUrl,preferred)"

    if ($Name -ne $null) {$Uri += "&name=$Name"}
    
    $List = Invoke-RestMethod $Uri
    return $List.Items
}

function Get-GoogleRestApi ($Uri, [bool]$RevisionOnly=$false, [bool]$RawContent=$false) {
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

#Params here only sort the results, they don't get passed to the API call
function Get-GoogleApiJsonFiles ($Name = $null, $Version = $null, $Preferred = $null) {

    $GoogleApiList = Get-GoogleApiList

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
            write-host "Downloading $JsonFileFolderName / $JsonFileName" -ForegroundColor Green
            #write-host $RestRevision
            if (-not (Test-Path ($JsonFileFolder))) {
                New-Item -Path $JsonFileFolder -ItemType "Directory" | Out-Null
            }

            Get-GoogleRestApi $ApiInfo.discoveryRestUrl -RawContent $true | Out-File -FilePath $JsonFilePath
        } else {
            Write-Host "$JsonFileFolderName / $JsonFileName already exists." -ForegroundColor DarkYellow
        }

        $JsonFileFolderName, $JsonFileFolderName, $JsonFileName, $JsonFilePath, $ApiInfo = $null
    }
}

function Get-MostRecentJsonFile ($Path) {
    $Files = New-Object System.Collections.ArrayList
    gci $Path | % {$Files.add($_) | Out-Null}

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
}

function Get-JsonApiFile ($Name, $Version) {
    $Folder = [System.IO.Path]::Combine($JsonRootPath, ("$Name.$Version"))
    return (Get-MostRecentJsonFile $Folder)
}

function Load-RestJsonFile ($Name, $Version) {
    $file = Get-JsonApiFile $Name $Version
    if ($file -ne $null) {
        $Json = Get-Content $file.FullName | ConvertFrom-Json
    }
    return $Json
}