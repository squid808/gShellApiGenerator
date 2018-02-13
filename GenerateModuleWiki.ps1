function Get-HtmlAnchor($AnchorText) {
    return "<a name=`"$AnchorText`"></a>"
}

function Write-Wiki {
[cmdletbinding()]

param($Api, [string]$ModulePath, [string]$ModuleVersion, [string]$HelpOutDirPath, [switch]$CustomVerbose)

    #Writes Verbose but only for a specific message - use to allow one-level verbosity
    function Write-CustomVerbose([string]$Message, [bool]$WriteVerbose) {
        if ($WriteVerbose -eq $true) {
            $OldVerbose = $VerbosePreference
            $VerbosePreference = "Continue"
            Write-Verbose $Message
            $VerbosePreference = $OldVerbose
        }
    }

    if ($null -eq (Get-Command -Module platyps)) {
        Write-CustomVerbose "Platyps not found, installing for current user" $CustomVerbose
        install-module platyps -Scope CurrentUser
    } else {
        Write-CustomVerbose "Platyps found" $CustomVerbose
    }
    
    Import-Module $ModulePath -DisableNameChecking
    
    $ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)

    $SubPath = [System.IO.Path]::Combine($HelpOutDirPath, $ModuleName)

    if (-not (test-path $SubPath)) {
        Write-CustomVerbose "$SubPath not found, creating..." $CustomVerbose
        New-Item -Path $SubPath -ItemType "Directory" -Force | Out-Null
        Write-CustomVerbose "Directory Created" $CustomVerbose
    }

    $Files = New-MarkdownHelp -Module $ModuleName -OutputFolder $SubPath -NoMetadata -AlphabeticParamsOrder -Force -ErrorAction SilentlyContinue #-HelpVersion $ModuleVersion

    Remove-Module $ModuleName

    #Build it in to one file
    $MainFileSB = new-object System.Text.StringBuilder

    $ApiDescription = $Api.DiscoveryObj.description
    $AssemblyVersion = $Api.AssemblyVersion
    $ApiName = $Api.NameAndVersion

    $TopAnchor = Get-HtmlAnchor "TopOfPage"

    $MainFileSB.AppendLine(@"

# $TopAnchor $ModuleName Module
## Description
$ApiDescription

## Version: $ModuleVersion
This document is representative of gShell.$ApiName (version $ModuleVersion), which is based on version $AssemblyVersion of the Google.Apis.$ApiName Client Library [available in Nuget](https://www.nuget.org/packages/Google.Apis.$ApiName/$AssemblyVersion).

## Installation
For installation, please visit [gShell.$ApiName in the PowerShell Gallery](https://www.powershellgallery.com/packages/gShell.$ApiName/$ModuleVersion).
"@) | Out-Null

    foreach ($File in $Files) {
        $Anchor = Get-HtmlAnchor [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        $MainFileSB.AppendLine("`r`n---`r`n`r`n$Anchor") | Out-Null
        $Content = (Get-Content $File.FullName) -join "`r`n"
        $MainFileSB.Append($Content) | Out-Null
        $MainFileSB.AppendLine("[Back to top](#TopOfPage)") | Out-Null
        Remove-Item $File.Fullname
    }

    $MainFileSB.ToString() | Out-File ([System.IO.Path]::Combine($SubPath, "$ModuleName.md")) -Force
}

Write-Wiki -ModulePath "C:\Users\svarney\Desktop\gShellGen\GenOutput\gShell.gmail.v1\bin\Debug\gShell.Gmail.v1.psd1" `
    -ModuleVersion "1.30.1034-alpha01" `
    -HelpOutDirPath "C:\Users\svarney\Documents\GshellAutomationTest.wiki" `
    -CustomVerbose