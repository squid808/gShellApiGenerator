function Get-HtmlAnchor($AnchorText) {
    return "<a name=`"$AnchorText`"></a>"
}

#TODO: Rename childresources dict to just Resources to allow for single-function recursion. And then offload it to the reflection
function Get-SubOrderedResources($Resource, [ref]$Results) {
    $R = $Results.Value
    
    $R.Add($Resource) | Out-Null
        
    foreach ($Child in $Resource.ChildResources) {
        Get-SubOrderedResources $Child ([ref]$R)
        #$R.AddRange($Children)
    }

    #return $R
}

function Get-OrderedResources ($Api) {
    $Results = New-Object System.Collections.ArrayList
    
    foreach ($Resource in $Api.Resources) {
        #$Results.Add($Resource) | Out-Null
        Get-SubOrderedResources $Resource ([ref]$Results)
    }

    return $Results
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

    gci $SubPath -Filter "*.md" | Remove-Item -Force

    $Files = New-MarkdownHelp -Module $ModuleName -OutputFolder $SubPath -NoMetadata `
        -AlphabeticParamsOrder -Force

    Remove-Module $ModuleName

    $OrderedResources = Get-OrderedResources $Api

    #Build it in to one file
    $MainFileSB = new-object System.Text.StringBuilder

    $ApiDescription = $Api.DiscoveryObj.description
    $AssemblyVersion = $Api.AssemblyVersion
    $ApiName = $Api.NameAndVersion

    $TopAnchor = Get-HtmlAnchor "TopOfPage"
    $IndexAnchor = Get-HtmlAnchor "ModuleList"
    $OCAnchor = Get-HtmlAnchor "ObjectCmdlets"

    $MainFileSB.AppendFormat(@"

# $TopAnchor $ModuleName
## Description
$ApiDescription

## Version: $ModuleVersion
This document is representative of gShell.$ApiName (version $ModuleVersion), which is based on version $AssemblyVersion of the Google.Apis.$ApiName Client Library [available in Nuget](https://www.nuget.org/packages/Google.Apis.$ApiName/$AssemblyVersion).

## Installation
For installation, please visit [gShell.$ApiName in the PowerShell Gallery](https://www.powershellgallery.com/packages/gShell.$ApiName/$ModuleVersion).

# {0}Cmdlet Index
"@, $IndexAnchor) | Out-Null

    foreach ($Resource in $OrderedResources) {

        $ResourceDotName = $Resource.FullName | % {if ($_ -match "(?<=v1.).*"){$Matches[0] -replace "Resource","" -replace "\+","."}}
        $DotNameAnchor = Get-HtmlAnchor $ResourceDotName

        $MainFileSB.AppendFormat("`r`n## {1}{0}`r`n", $ResourceDotName,$DotNameAnchor) | Out-Null

        foreach ($Method in $Resource.Methods) {
            $Cmdlet = $Method.MethodVerb + "-" + $Method.MethodNoun
            $MainFileSB.AppendFormat("[[{0}]] - ", $Cmdlet) | Out-Null
            if ($Method.Description -match "^([^.]+[.])") {
                $Description = $Matches[0]
            } else {
                $Description = $Method.Description
            }
            $MainFileSB.AppendFormat("{0}  `r`n", $Description) | Out-Null
        }

    }

    #now add the object files
    $MainFileSB.AppendFormat("`r`n`## {0}New-Object Cmdlets  `r`n", $OCAnchor) | Out-Null
    $MainFileSB.AppendLine("These cmdlets provide easier access to objects you may need above.") | Out-Null

    foreach ($ObjFile in (gci $SubPath -Filter "New*Obj.md")) {
        $Cmdlet = [System.IO.Path]::GetFileNameWithoutExtension($ObjFile.Name)
        $MainFileSB.AppendFormat("[[$Cmdlet]]  `r`n") | Out-Null
    }

    #foreach ($File in $Files) {
    #    $Anchor = Get-HtmlAnchor [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    #    $MainFileSB.AppendLine("`r`n---`r`n`r`n$Anchor") | Out-Null
    #    $Content = (Get-Content $File.FullName) -join "`r`n"
    #    $MainFileSB.Append($Content) | Out-Null
    #    $MainFileSB.AppendLine("[Back to top](#TopOfPage)") | Out-Null
    #    Remove-Item $File.Fullname
    #}

    $MainFileSB.ToString() | Out-File ([System.IO.Path]::Combine($SubPath, "$ModuleName.md")) -Encoding default -Force
}


Write-Wiki -ModulePath "C:\Users\svarney\Desktop\gShellGen\GenOutput\gShell.gmail.v1\bin\Debug\gShell.Gmail.v1.psd1" `
    -ModuleVersion "1.30.1034-alpha01" `
    -HelpOutDirPath "C:\Users\svarney\Documents\GshellAutomationTest.wiki" `
    -CustomVerbose -Api $Api
    