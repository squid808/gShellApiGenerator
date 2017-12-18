function Write-ModuleManifest ($Api, $ProjectRoot) {

    #$ProjectRoot = "$env:USERPROFILE\Desktop\GenOutput\gShell.gmail.v1"
    $ProjectDebugFolder = [System.IO.Path]::Combine($ProjectRoot, "bin\Debug")

    $Guid = ([xml](get-content (gci $ProjectRoot -Filter *.csproj).FullName)).Project.ChildNodes[1].ProjectGuid
    if (((get-content "$ProjectRoot\Properties\AssemblyInfo.cs") `
            -split "`r`n" | where {$_.Contains("AssemblyDescription")}) -match '".*"')
    {
        $Description = $Matches[0]
    }

    if (((get-content "$ProjectRoot\Properties\AssemblyInfo.cs") `
            -split "`r`n" | where {$_.Contains("AssemblyVersion")}) -match '(?<=").*(?=")')
    {
        $Version = $Matches[0]
    }

    $Author = "Spencer Varney"

    $ApiName = $Api.Name
    $ApiVersionNoDots = $Api.Version -replace "[.]","_"

    $ModuleName = "gShell.$ApiName.$ApiVersionNoDots"

    New-ModuleManifest `
        -Path "$ProjectDebugFolder\$ModuleName.psd1" `
        -Author $Author `
        -Guid $Guid `
        -CompanyName $Author `
        -Copyright ("(c) {0} $Author. All rights reserved." -f (Get-Date -Format "yyyy")) `
        -Description $Description `
        -ModuleVersion $Version `
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
}