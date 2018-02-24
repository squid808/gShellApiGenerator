function Write-ModuleManifest ($Api, $Version, $ProjectRoot) {

    #$ProjectRoot = "$env:USERPROFILE\Desktop\GenOutput\gShell.gmail.v1"
    $ProjectDebugFolder = [System.IO.Path]::Combine($ProjectRoot, "bin\Debug")

    $Guid = ([xml](get-content (gci $ProjectRoot -Filter *.csproj).FullName)).Project.ChildNodes[1].ProjectGuid
    if (((get-content "$ProjectRoot\Properties\AssemblyInfo.cs") `
            -split "`r`n" | where {$_.Contains("AssemblyDescription")}) -match '".*"')
    {
        $Description = $Matches[0]
    }

    #if (((get-content "$ProjectRoot\Properties\AssemblyInfo.cs") `
    #        -split "`r`n" | where {$_.Contains("AssemblyVersion")}) -match '(?<=").*(?=")')
    #{
    #    $Version = $Matches[0]
    #}

    #Make sure the version is only 3 places long and allow for alpha options
    #$Split = $Version.Split(".")
    #$Version = ($Split[0], $Split[1], ($Split[2] + $Split[3]) -join ".")
    #$PrereleaseVersion = "-alpha01"

    $Author = "Spencer Varney"

    $ApiName = $Api.Name
    $ApiVersionNoDots = $Api.Version -replace "[.]","_"

    $ModuleName = "gShell.$ApiName.$ApiVersionNoDots"

    $Matches = $null

    if ($Version -match "-.*") {
        $AlphaVersion = "'{0}'" -f $Matches[0]
    }

    New-ModuleManifest `
        -Path "$ProjectDebugFolder\$ModuleName.psd1" `
        -Author $Author `
        -Guid $Guid `
        -CompanyName $Author `
        -Copyright ("(c) {0} $Author. All rights reserved." -f (Get-Date -Format "yyyy")) `
        -Description $Description `
        -ModuleVersion $Version.Split("-")[0] `
        -PowerShellVersion 4.0 `
        -DotNetFrameworkVersion "4.5.1" `
        -NestedModules @(
            ".\gShell.Main.dll"
            ".\$ModuleName.dll"
        ) `
        -CmdletsToExport "*" `
        -ModuleList @(
            ".\gShell.Main.dll"
            ".\$ModuleName.dll"
        ) `
        -RootModule ".\$ModuleName.dll" `
        -ProjectUri "https://github.com/squid808/gShell" `
        -LicenseUri "https://github.com/squid808/gShell/blob/master/LICENSE"

        $P = (get-content "$ProjectDebugFolder\$ModuleName.psd1") -join "`r`n"

        $P.Replace("    } # End of PSData hashtable",@"
        # Prerelease Version
        Prerelease = $AlphaVersion
    } # End of PSData hashtable
"@) | Out-File -FilePath "$ProjectDebugFolder\$ModuleName.psd1"
}""