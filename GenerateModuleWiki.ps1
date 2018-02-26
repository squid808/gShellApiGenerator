#Returns an anchor text in a formatted anchor
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

#Get all resources, including sub-resources, in a single flat list
function Get-OrderedResources ($Api) {
    $Results = New-Object System.Collections.ArrayList
    
    foreach ($Resource in $Api.Resources) {
        Get-SubOrderedResources $Resource ([ref]$Results)
    }

    return $Results
}

#Outputs the wiki files including the main module page for a single API
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

    $MainFileSB = new-object System.Text.StringBuilder

    $ApiDescription = $Api.DiscoveryObj.description
    $AssemblyVersion = $Api.AssemblyVersion
    $ApiName = $Api.NameAndVersion

    $TopAnchor = Get-HtmlAnchor "topofpage"
    $MCAnchor = Get-HtmlAnchor "methodcmdlets"
    $OCAnchor = Get-HtmlAnchor "objectcmdlets"

    $MainFileSB.AppendFormat(@"

# $TopAnchor $ModuleName
## Description
$ApiDescription

## Version: $ModuleVersion
This document is representative of gShell.$ApiName (version $ModuleVersion), which is based on version $AssemblyVersion of the Google.Apis.$ApiName Client Library [available in Nuget](https://www.nuget.org/packages/Google.Apis.$ApiName/$AssemblyVersion).

## Installation
For installation, please visit [gShell.$ApiName in the PowerShell Gallery](https://www.powershellgallery.com/packages/gShell.$ApiName/$ModuleVersion).

# {0}Cmdlet Index
"@, $MCAnchor) | Out-Null

    foreach ($Resource in $OrderedResources) {

        $ResourceDotName = $Resource.FullName | % {if ($_ -match "(?<=v1.).*"){$Matches[0] -replace "Resource","" -replace "\+","."}}
        $DotNameAnchor = Get-HtmlAnchor $ResourceDotName

        $MainFileSB.AppendFormat("`r`n## {1}{0}`r`n", $ResourceDotName,$DotNameAnchor) | Out-Null

        $MainFileSB.Append("<dl>`r`n") | Out-Null
        foreach ($Method in $Resource.Methods) {
            $Cmdlet = $Method.MethodVerb + "-" + $Method.MethodNoun
            $MainFileSB.AppendFormat("  <dt>[[{0}]]</dt>", $Cmdlet) | Out-Null
            if ($Method.Description -match "^([^.]+[.])") {
                $Description = $Matches[0]
            } else {
                $Description = $Method.Description
            }
            $MainFileSB.AppendFormat("    <dd>{0}</dd>`r`n", $Description) | Out-Null
        }
        $MainFileSB.Append("</dl>`r`n`r`n") | Out-Null
        $MainFileSB.Append("<sub>[Back To Top](#topofpage) | [[API Modules Index|ModulesIndex]]</sub>`r`n") | Out-Null

    }

    #now add the object files
    $MainFileSB.AppendFormat("`r`n`## {0}New-Object Cmdlets  `r`n", $OCAnchor) | Out-Null
    $MainFileSB.AppendLine("These cmdlets provide easier access to objects you may need above.  ") | Out-Null

    foreach ($ObjFile in (gci $SubPath -Filter "New*Obj.md")) {
        $Cmdlet = [System.IO.Path]::GetFileNameWithoutExtension($ObjFile.Name)
        $MainFileSB.AppendFormat("* [[$Cmdlet]]  `r`n") | Out-Null
    }

    foreach ($File in $Files) {
        Write-CustomVerbose $File.Name $CustomVerbose
        $Content = (Get-Content $File.FullName)
        $Noun = $File.Name.Split("-")[1].Split(".")[0]
        $Related = $Files | where {$_.name -like "*-$Noun.md" -and $_ -ne $file} | select -ExpandProperty Name | % {$_.Replace(".md","")}
        $WithLinks = Add-WikiCmdletLinks -ModuleName $ModuleName -FileContent $Content -RelatedCmdlets $Related
        ($WithLinks -join "`r`n") | Out-File $File.FullName -Encoding default -Force
    }

    $MainFileSB.ToString() | Out-File ([System.IO.Path]::Combine($SubPath, "$ModuleName.md")) -Encoding default -Force

    return $Files
}

#Add navigation links to a single cmdlet's page/file
function Add-WikiCmdletLinks ($ModuleName, $FileContent, $RelatedCmdlets)  {
    $TopAnchor = Get-HtmlAnchor "topofpage"
    $LinksLine = "<sub>[Back To Top](#topofpage) | [[$ModuleName Index|$ModuleName]] | [[API Modules Index|ModulesIndex]]</sub>"
    $TopLinks = @("[Synopsis](#synopsis)","[Syntax](#syntax)","[Description](#description)","[Examples](#examples)",
        "[Parameters](#parameters)","[Inputs](#inputs)","[Outputs](#outputs)","[Notes](#notes)","[Related Links](#related-links)") -join " | "
    
    $LinksHeaderToMatch = "^##\s"

    $passedFirstHeader = $false

    $FileContent[0] = ($FileContent[0] -split " " -join " $TopAnchor")
    $FileContent[0] += "`r`n$TopLinks"

    for ($i = 0; $i -lt $FileContent.Length; $i++) {
        if ($FileContent[$i] -match $LinksHeaderToMatch) {

            #Add in anchor nav links above if not the first one
            if ($passedFirstHeader -eq $true) {
                $FileContent[$i-2] += "  "
                $FileContent[$i-1] = "$LinksLine`r`n`r`n" + $FileContent[$i-1]
            } else  {
                $passedFirstHeader = $true
            }
        }

        if ($FileContent[$i] -eq "## RELATED LINKS") {
            for ($j = $i+1; $j -lt $FileContent.Length; $j++) {$FileContent[$j] = ""}
            $FileContent[$i] += "`r`n`r`n" + (($RelatedCmdlets | % {"[[$_]]"}) -join "  `r`n") + ("`r`n`r`n" + $LinksLine)
        }
    }

    return $FileContent
}

function New-WikiMarkdownApiTable ($LibraryIndex, $Apis) {

    $Content = New-Object System.Collections.ArrayList
    $ModulesWithCmdlets = 0
    $CmdletsTotal = 0
    
    $GShellLibs = $LibraryIndex.GetLibAll() | where {$_ -match "^gShell"}

    $Header = @"

| Google API | Most Recent <br>Successful Version | Most Recent <br>Build Status |
| ---------------------------------------- | :------------: | :------------: |
"@

    $Content.Add($Header) | Out-Null

    foreach ($Api in $Apis) {

        $NA = $false
        if ($Api -like "*gmail*") {
            write-host ""
}
        $Info = $LibraryIndex.GetLib("gShell.$Api")
        if ($null -ne $Info) {
            if ([string]::IsNullOrWhiteSpace($Info.LastSuccessfulVersionBuilt)) {
                $NA = $true
            } else {
                $Version = "[{0}]({1})" -f $Info.LastSuccessfulVersionBuilt, ("gShell.$Api")
                $SuccessfulCmdletCount = $Info.Versions.($Info.LastSuccessfulVersionBuilt).CmdletCount
                if ($SuccessfulCmdletCount -gt 0) {
                    $CmdletsTotal += $SuccessfulCmdletCount
                    $ModulesWithCmdlets += 1
                }
                $LastBuilt = $LibraryIndex.GetLibLastVersionBuilt("gShell.$Api")
                if ($Info.Versions.$LastBuilt.SuccessfulGeneration -eq $true) {
                    $Status = "![Built][shieldBuilt]"
                } else {
                    $Status = "![Failed][shieldFailed]"
                }
            }
        } else {
            $NA = $true
        }

        if ($NA -eq $true) {
            $Version = "-"
            $Status = "![NA][shieldNA]"
        }

        #First, if  the api name != the RestNameAndVersion, it was redirected. Which one to use?
        $Line = "| {0} | {1} | {2} |" -f $Api, $Version, $Status
        $Content.Add($Line) | Out-Null
    }

    $Content = ($Content -join "`r`n") + "`r`n<sub>[Back To Top](#topofpage)</sub>"
    
    return $Content, $ModulesWithCmdlets, $CmdletsTotal

}

function Make-ApiModulePage ($LibraryIndex, [string]$HelpOutDirPath, $PerTable=15) {
    $TopOfPageAnchor = Get-HtmlAnchor "topofpage"

    $KnownApis = $LibraryIndex.GetLibAll() | where {$_ -match "Google.Apis\..+"}

    $ContentCollection = New-Object System.Collections.ArrayList

    $Content = @"
# $TopOfPageAnchor Modules
Below is the list of APIs that have been processed by the [gShell Api Generator](https://github.com/squid808/gShellApiGenerator), along with the most recent successful version's documentation as well as the most recent attempted build status.  
{3}

## Stats

#### Total APIs: {0}

#### Total Modules: {1}

#### Total Cmdlets: {2} 

## Modules

[shieldBuilt]: https://img.shields.io/badge/-Built-green.svg "Build Succeeded"
[shieldFailed]: https://img.shields.io/badge/-Failed-red.svg "Build Failed"
[shieldNA]: https://img.shields.io/badge/-N/A-lightgrey.svg "Not Available"

"@

    #$ContentCollection.Add($Content) | Out-Null

    #$GShellLibs = $LibraryIndex.GetLibAll() | where {$_ -match "^gShell"} | where {$_ -ne "gShell.Main"} | sort

    $Libs = $LibraryIndex.GetLibAll() | where {$_ -match "^Google\.Apis\..+"}  | % {$_ -replace "Google.Apis.",""} | sort

    #To use in keeping track of the letters index
    $RecentLetter = $null
    $ModulesWithCmdlets = 0
    $CmdletsCount = 0

    #if 14 -ge 14 end = len - 1
    for ($i = 0; $i -lt $Libs.Length; $i+=$PerTable) {
        $end = $i + $PerTable - 1

        if ($end -ge $Libs.Length) {
            $end = $Libs.Length - 1
        }

        $Table,$TableModulesWithCmdlets,$TableCmdletsCount = `
            New-WikiMarkdownApiTable -LibraryIndex $LibraryIndex -Apis $Libs[$i..$end]
        $ModulesWithCmdlets += $TableModulesWithCmdlets
        $CmdletsCount += $TableCmdletsCount
        $ContentCollection.Add($Table) | Out-Null
    }

    $Letters = [ordered]@{}
    65..90 | % {$Letters[[string]([char]$_)] = $false}
    $LetterIndex = New-Object System.Collections.ArrayList

    $ContentCollection = $ContentCollection -join "`r`n" -split "`r`n"

    #Add anchors to any lines with letters, and update the dict
    foreach ($Letter in $Letters.Keys) {

        $LetterSearch = ($ContentCollection | ? {$_ -match "^\| $Letter" -and $_ -notmatch "Google API" } | select -First 1)
        if (-not [string]::IsNullOrWhiteSpace($LetterSearch)){
            $LetterLower = $Letter.ToLower()
            $LetterIndex.Add(("[$Letter](#modules-$LetterLower)")) | Out-Null
            $LetterLine = $ContentCollection.IndexOf($LetterSearch)
            $ContentCollection[$LetterLine] = $LetterSearch.Insert(2,(Get-HtmlAnchor "modules-$LetterLower"))
        } else {
            $LetterIndex.Add($Letter) | Out-Null
        }
    }

    $LetterIndex = $LetterIndex -join " "

    $Content = $Content -f $Libs.Count, $ModulesWithCmdlets, $CmdletsCount, $LetterIndex

    $Text = $Content + ($ContentCollection -join "`r`n")

    $Text | Out-File ([System.IO.Path]::Combine($HelpOutDirPath, "ModulesIndex.md")) -Encoding default -Force
}

#$RestJson = Load-RestJsonFile gmail v1
#$LibraryIndex = Get-LibraryIndex $LibraryIndexRoot -Log $Log
#$Api = Invoke-GShellReflection -RestJson $RestJson -ApiName "Google.Apis.Gmail.v1" -ApiFileVersion "1.30.0.1034" -LibraryIndex $LibraryIndex
#
#$Files = Write-Wiki -ModulePath "C:\Users\svarney\Desktop\gShellGen\GenOutput\gShell.gmail.v1\bin\Debug\gShell.Gmail.v1.psd1" `
#    -ModuleVersion "1.30.1034-alpha01" `
#    -HelpOutDirPath "C:\Users\svarney\Documents\GshellAutomationTest.wiki" `
#    -CustomVerbose -Api $Api

Make-ApiModulePage -LibraryIndex $LibraryIndex -HelpOutDirPath $WikiRepoPath