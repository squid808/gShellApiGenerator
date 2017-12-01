$ProjectRoot = "$env:USERPROFILE\Desktop\GenOutput\gShell.gmail.v1"
$ProjectDebugFolder = [System.IO.Path]::Combine($ProjectRoot, "bin\Debug")

$Guid = ([xml](get-content "$ProjectRoot\gShell.Gmail.v1.csproj")).Project.ChildNodes[1].ProjectGuid
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

New-ModuleManifest `
    -Path "$ProjectDebugFolder\gShell.Gmail.psd1" `
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
        ".\gShell.Gmail.v1.dll"
    ) `
    -CmdletsToExport "*" `
    -ModuleList @(
        ".\gShell.Main.dll"
        ".\gShell.Gmail.v1.dll"
    ) `
    -RootModule ".\gShell.Gmail.v1.dll"