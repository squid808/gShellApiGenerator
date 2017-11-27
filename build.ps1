$BuildDir = "$env:windir\Microsoft.NET\Framework\v4.0.30319"
$BuildExe = "$BuildDir\MSBuild.exe"

function Get-ApiPackagesXml ($LibraryIndex, $DependenciesChain) {
    $Packages = New-Object system.collections.arraylist

    $latestGoogleAuthVersion = $LibraryIndex.GetLibVersionLatestName("Google.Apis.Auth")
    $packageFormatString = '  <package id="{0}" version="{1}" targetFramework="net451" />'

    $Exclusions = @("System.Net.Http", "System.Management.Automation.dll")

    foreach ($D in $DependenciesChain.GetEnumerator()) {
        if ($Exclusions -notcontains $D.Name) {
            Add-String $Packages ($packageFormatString -f $D.Name, $D.Value)
        }
    }

    Add-String $Packages ($packageFormatString -f "System.Management.Automation.dll", "10.0.10586.0")

    $PackagesText = $Packages -join "`r`n"

    return $PackagesText
}

function Build-ApiLibrary ($LibraryIndex, $ApiName, $RootOutPath) {
    $LatestDllVersion = $LibraryIndex.GetLibVersionLatestName($ApiName)

    $LastVersionBuilt = $LibraryIndex.GetLibLastVersionBuilt($ApiName)

    if ($LastVersionBuilt -eq $null -or $LastVersionBuilt -ne $LatestDllVersion) {

        $gShellVersions = $LibraryIndex.GetLibVersionAll("gShell.Main")

        $LatestDependencyChain = $LibraryIndex.GetLibVersionDependencyChain($ApiName, $LatestDllVersion)

        $LatestAuthVersion = $LatestDependencyChain.'Google.Apis.Auth'

        $gShellVersionToUse = $LibraryIndex.GetLibVersionAll("gShell.Main") | % {`
            if (($_.Value.Dependencies | where {$_.Name -eq "Google.Apis.Auth" -and $_.Versions -like "*1.*"}) -ne $null) { `
                $_.Name `
            }} `
            | sort -Descending | select -First 1

        if (-not [string]::IsNullOrWhiteSpace($gShellVersionToUse)) {
            $gShellDependencyChain = $LibraryIndex.GetLibVersionDependencyChain("gShell.Main", $gShellVersionToUse)

            #sync the dependencies for this gshell version with this api
            foreach ($pair in $gShellDependencyChain.GetEnumerator()) {
                $LatestDependencyChain[$pair.name] = $pair.Value
            }

            #Now we need to generate the files and get the csproj location
            $dllPath = $LibraryIndex.GetLibVersion($ApiName, $LatestDllVersion).dllPath

            $RestNameAndVersion = $LibraryIndex.GetLibRestNameAndVersion($ApiName)

            $JsonFileInfo = Get-MostRecentJsonFile -Path ([System.IO.Path]::Combine($JsonRootPath, $RestNameAndVersion))

            $RestJson = Get-Content $JsonFileInfo.FullName | ConvertFrom-Json

            #START HERE
            Create-TemplatesFromDll -LibraryIndex $LibraryIndex -ApiName $ApiName -ApiFileVersion $LatestDllVersion `
                -OutPath ([System.IO.Path]::Combine($RootOutPath, ("gShell.$RestNameAndVersion"))) `
                -RestJson $RestJson

        } else {
            throw "gShell version $LatestAuthVersion not found for $ApiName"
        }
    }
}

$LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log
Build-ApiLibrary -LibraryIndex $LibraryIndex -ApiName "Google.Apis.Gmail.v1" -RootOutPath $RootProjPath