﻿#TODO: make all lines return as arraylists and only join at the end to prevent having to split apart lines for wrapping and tabbing?
#TODO: make each write method take in an [indent] level param to determine indents, and handle tabbing and wrapping before returning?
#TODO: incorporate set-indent and wrap-text?
#TODO: determine impact of ApiVersionNoDots on APIs that have underscores already - what are their namespaces?
#TODO: remove need for StandardParamsCmdletBase by implementing a root class for each API that contains the respective standard params, if any
#TODO: determine when the service account variables should be added and when other similar variables should be added
#TODO: include logic in reflection to indicate if API should include std query params and service accounts to put it in one place
#TODO: Fix casing on parameters
#TODO: Add $PropertiesObjVarName and *Lower to method
#TODO:  Make links for *Obj cmdlets point to a single wiki page
#TODO: Anything that is text as a first-line should wrap and indent only itself, and THEN should bring in variables that are also indented. also, anything that has a text
#       description in it should also be wrapped separately
#TODO: Update Body Parameter reference to use regular parameter
#TODO: Rename Api-Class to something about schema
#TODO: Remove ETag filtering from templates
#TODO: Update referecens in reflection so all objects have an API reference? clean up Get-ApiPropertyTypeShortName references
#TODO: Look into datetime options
#TODO: Hard-code in the scopes if needed? Will need to figure that out.
#TODO: Remove erroneous standard query params from media uplods

<#

sections of code:
    In Cmdlets:
        1) The *Obj cmdlets
        2) the actual gshell cmdlets code
    In DotNet:
        1) The gShell.Cmdlets.[API] *Base class containing wrapped method calls (between cmdlets and dotnet)
        2) gShell.dotNet with the IServiceWrapper class and subclasses to define resources, methods, properties
    Other Files:
        1) Cmdlet Help File
        2) Wiki Pages (depreciate and point online help to google api pages instead? or maybe one page per API with anchors?)
#>

#region Helpers

function Get-CharCountInString([string]$String, $Char) {
    $result = 0
    
    for ($i = 0; $i -lt $String.Length; $i++) {
        if ($String[$i] -eq $Char) {
            $result++
        }
    }

    return $result
}

#take in a block of text and wrap any lines longer than 120 lines
function Wrap-Text ($Text, $Level=0, $Padding=0, $PrependText=$null, [bool]$Debug=$false) {

    $OriginalPadding = $padding 

    $lines = $Text -split "`r`n"
    if ($Debug) {write-host ("Calling Wrap-Text at level = $Level, Padding = $Padding, splitting in to {0} lines." -f $Lines.count) -ForegroundColor White -BackgroundColor Black}

    for ($l = 0; $l -lt $lines.Count; $l++){
        if ($Debug) {write-host ("Working on line:`r`n{0}" -f $lines[$l]) -ForegroundColor Cyan}

        #if the prepend text is present, make sure it's applied after whitespace - mostly for multiline comments
        if (-not [string]::IsNullOrWhiteSpace($PrependText) -and $lines[$l] -notmatch "^\s*$PrependText") {
            if ($Debug) {write-host "Adding prepend text"}
            $lines[$l] = $lines[$l].Insert(0,$PrependText)
        }

        #if padding is not in the line after whitespace, make sure it's applied - mostly for multiline comments
        if ($level -eq 0) {
            if ($OriginalPadding -ne 0) {
                if ($Debug) {write-host "Adding in original padding"}
                $lines[$l] = $lines[$l].Insert(0,(" "*$OriginalPadding))
            } else {
                $Padding = 0
            }
        }

        if ($lines[$l].Length -gt 120) {
            if ($Debug) {write-host ("Line has length of {0}" -f $Lines[$l].Length)}
            
            $StartInd = 119

            $BreakInString = $false
            
            $LineBreakPattern = "[\s\)\],]"
            
            #determine padding if not already calculated and provided
            if ($level -eq 0 -and $padding -eq 0) {

                if ($lines[$l] -match "[^\s]") {
                    $padding = $lines[$l].IndexOf($matches[0])

                    if ($Debug) {write-host "Determining initial padding is $padding whitespaces"}
                }
            }

            #go backwards until padding to see if we can make a break match
            for ($i = $StartInd; $i -ge $Padding+1; $i--) {
                if ($lines[$l][$i] -match $LineBreakPattern) {

                    if ($Debug) {write-host "Found a line break match at line index $i, new line is:"}
                    if ($Debug) {write-host ("{0}" -f $lines[$l].Substring(0,($i+1))) -ForegroundColor Blue -BackgroundColor White} 

                    #if the break is in the middle of a string
                    if ((Get-CharCountInString $lines[$l].Substring(0,$i) '"')%2 -eq 1){

                        #if ($Debug) {write-host ("{0}" -f $lines[$l].Substring(0,$i)) -ForegroundColor Blue -BackgroundColor White} 
                        if ($Debug) {write-host "This breaks a string. adjusting start index"}

                        #since a break in a string would add a close quote and a plus, let's find out if that would make it too big
                        if ($i + 2 -ge 120) {
                            if ($Debug) {write-host "Adding the break here would make the string too long, trying again"}
                            continue
                        } else {
                            $BreakInString = $true
                        }
                    }
                    
                    #set the recursive padding for any sub-lines (which may not be applied if a comment string)
                    if ($Level -eq 0) {

                        if ($Debug) {write-host "Adding 4 padding"}
                        $paddingplus = 4
                    }

                    #if this is a comment line that can be broken up make sure sub-lines have /// as well
                    if ($lines[$l] -match "^\s*///") {
                        if ($lines[$l].Substring(0,($i+1)) -notmatch "^\s*///\s*$") {
                            if ($Debug) {write-host "This line appears to be a /// comment, adding to next line"}
                            #the second match is to make sure we're not just left with /// at the beginning, which would cause
                            #an infinite call stack
                            $ToInsert = "`r`n{0}/// " -f (" "*$padding)
                        } else {
                            if ($Debug) {write-host "This line is a /// comment, but cannot be broken up"}
                            break
                        }
                    } else {
                        if ($lines[$l].Substring(0,($i+1)) -notmatch "^\s*$") { 
                            #handle breaking strings with a "" + ""
                            if ($BreakInString -eq $true) {
                                $ToInsert = "`"+`r`n{0}`"" -f (" "*($padding+$paddingplus))
                                if ($Debug) {write-host "Creating a + and line break for the string"}
                            } else {
                                $ToInsert = "`r`n{0}" -f (" "*($padding+$paddingplus))
                                if ($Debug) {write-host "Creating a line break for the string"}
                            }
                        } else {
                            if ($Debug) {write-host "This split would create an empty string and therefore cannot be broken up"}
                            break
                        }
                    }

                    #insert the break string at the breakpoint
                    if ($Debug) {write-host "Adding the linebreak in the string  at index $i"}
                    $lines[$l] = $lines[$l].Insert(($i+1), $ToInsert)

                    $lines[$l] = Wrap-Text $lines[$l] -Level ($Level+1) -Padding $padding -PrependText $PrependText -Debug $Debug
                    
                    break
                }
            }
        }
    }

    if ($Debug -and $Level -gt 0) {write-host ("Returning to level " + ($Level -1)) -ForegroundColor White -BackgroundColor Black}
    return $lines -join "`r`n"
}

#take in a block of text and replace indent markers with a four-space tab
function Set-Indent ([string]$String, [int]$TabCount, [string]$TabPlaceholder = "{%T}") {
    return ($String -replace $TabPlaceholder,("    "*$TabCount))
}

#Returns a parent resource chain, if any exists. if the given object is top-level, result is blank
function Get-ParentResourceChain ($MethodOrResource, $JoinChar = ".", [bool]$UpperCase=$true) {
    if ($MethodOrResource.ParentResource -ne $null) {
        $ChainFromParent = (Get-ParentResourceChain $MethodOrResource.ParentResource `
            -JoinChar $JoinChar -UpperCase $UpperCase)
        
        $Name = if ($UpperCase -eq $true){ 
            $MethodOrResource.ParentResource.Name 
        } else {
            $MethodOrResource.ParentResource.NameLower
        }

        if ($ChainFromParent -ne $null) {
            $result = $ChainFromParent, $Name -join $JoinChar
        } else {
            $result = $Name
        }
    }

    return $result
}

#Repairs comment strings such that empty lines and line breaks are replaced with ///
function Format-CommentString ($String) {
    $fixed = $string -replace "(?:`n|`r`n?)","`r`n/// "
    return $fixed
}

function Format-HelpMessage ($String) {
    $fixed = $string -replace "(?:`n|`r`n?)","\r\n"
    return $fixed
}

function Test-StringHasContent ([string]$String) {
    return (-not [string]::IsNullOrWhiteSpace($String))
}

Set-Alias -Name Test-String -Value Test-StringHasContent

function Add-String ([System.Collections.ArrayList]$Collection, [string]$String) {
    if (Test-String $String) {
        $Collection.Add($string) | Out-Null
    }
}

function Get-MediaDownloadProperty($Method) {
    $P = New-Object ApiMethodProperty
    $P.Method = $Method
    $P.Api = $Method.Api
    $P.Name = "DownloadPath"
    $P.NameLower = "downloadPath"
    $P.Required = $true
    $P.Description = "The target download path of the file, including filename and extension."
    $P.Type = "string"
    $P.CustomProperty = $true

    return $P
}

function Get-MediaUploadProperty($Method) {
    $P = New-Object ApiMethodProperty
    $P.Method = $M
    $P.Api = $M.Api
    $P.Name = "SourceFilePath"
    $P.NameLower = "sourceFilePath"
    $P.Required = $true
    $P.Description = "The path of the target file to upload, including filename and extension."
    $P.Type = "string"
    $P.CustomProperty = $true

    return $P
}

$GeneralFileHeader = @"
// gShell is licensed under the GNU GENERAL PUBLIC LICENSE, Version 3
//
// http://www.gnu.org/licenses/gpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// gShell is based upon https://github.com/google/google-api-dotnet-client, which is licensed under the Apache 2.0
// license: https://github.com/google/google-api-dotnet-client/blob/master/LICENSE
//
// gShell is reliant upon the Google Apis. Please see the specific API pages for specific licensing information.

//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by the gShell Api Generator:
//       https://github.com/squid808/gShellApiGenerator
//
//     How neat is that? Pretty neat.
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

"@
#endregion

#region Templating

#region CSProj

function Write-CSPReferenceHintPath {
    param (
        [Parameter(ParameterSetName = "Created")]
        $Name,
        
        [Parameter(ParameterSetName = "Created")]
        $Version,
        
        [Parameter(ParameterSetName = "Created")]
        $TargetFramework = "net45",

        [Parameter(ParameterSetName = "Provided")]
        $HintPath,

        $IsConditional = $false
    )

    if ($PSCmdlet.ParameterSetName -eq "Created") {
        $Path = "packages\$Name.$Version\lib\$TargetFramework\$Name.dll"
    } else {
        $Path = $HintPath
    }

    if ($IsConditional -eq $true) {
        $Folder = [System.IO.Path]::GetDirectoryName($Path)
        $Conditional = " Condition=`"Exists('$Folder')`""
    }

    $HintTag = "      <HintPath$Conditional>$Path</HintPath>"

    return $HintTag
}

function Write-CSPReference($Name, $Version, $HintPath1, $HintPath2 = $null, $Private = $null) {

    if ($private -ne $null) {
        $Private = $Private.ToString()
        $PrivateText = "      <Private>$Private</Private>"
    }

    $text = New-Object system.collections.arraylist

    add-string $text "    <Reference Include=`"$Name, Version=$Version`">"
    add-string $text $HintPath1
    add-string $text $HintPath2
    add-string $text $PrivateText
    add-string $text "    </Reference>"

    $textBlock = $text -join "`r`n"

    return $textBlock
}

function Write-CSPReferenceTexts($Api, $LibraryIndex) {

    $ReferencesTexts = New-Object system.collections.arraylist

    $ReferenceChain = $LibraryIndex.GetLibVersionDependencyChain($Api.RootNamespace, $LibraryIndex.GetLibVersionLatestName($Api.RootNamespace))

    foreach ($Key in $ReferenceChain.Keys) {
        Add-String $ReferencesTexts (Write-CSPReference $Key $ReferenceChain[$Key])
    }

    $ReferencesTexts = ($ReferencesTexts | Sort) -join "`r`n"

    return $ReferencesTexts
}

#endregion



#region SQP, SQPB (Standard Query Parameters & Base)

function Write-SQP ($Api) {
    $ApiName = $Api.Name
    $ApiNameAndVersion = $Api.NameAndVersion
    $ApiRootNamespace = $Api.RootNamespace
    $StdQParamsName = $Api.Name + "StandardQueryParameters"
    $Params = New-Object System.Collections.ArrayList

    foreach ($Param in $Api.StandardQueryParams) {
        if ($Param.type -ne $null) {
            $Summary = Wrap-Text (("        /// <summary> {0} </summary>" -f (Format-CommentString $Param.description)))
            $Property = "        public {0} {1} {{ get; set; }}" -f $Param.type, $Param.NameLower

            Add-String $Params ($Summary + "`r`n" + $Property)
        }
    }

    $ParamsText = $Params -join "`r`n`r`n"

    $text = @"
$GeneralFileHeader

using $ApiRootNamespace;
using $ApiRootNamespace.Data;

namespace gShell.$ApiNameAndVersion
{
    /// <summary> Standard Query Parameters for the $ApiName Api. </summary>
    public class $StdQParamsName
    {
$ParamsText
    }
}
"@

    return $text
}

function Write-SQPB ($Api) {
    $ApiName = $Api.Name
    $ApiNameAndVersion = $Api.NameAndVersion
    $ApiRootNamespace = $Api.RootNamespace

    $StdQParamsName = $Api.Name + "StandardQueryParameters"
    $StdQParamsBase = $Api.StandardQueryParamsBaseType

    $Params = New-Object System.Collections.ArrayList

    foreach ($Param in $Api.StandardQueryParams) {
            $Help = Format-HelpMessage $Param.description
            $ParamAttributes = Wrap-Text "    [Parameter(Mandatory = false, HelpMessage = `"$Help`")]"
            $Signature = "        public {0} {1} {{ get; set; }}" -f $Param.type, $Param.NameLower

            Add-String $Params ($Summary + "`r`n" + $Property)
        }

    $ParamsText = $Params -join "`r`n`r`n"
    $ParamAttribute = Wrap-Text (("        [Parameter(Mandatory = false, HelpMessage = `"The standard query parameters " +
            "for this Api, created with New-G{0}StandardQueryParameters or by creating a new object of " +
            "type gShell.{1}.{2}`")]") -f $Api.Name, $Api.NameAndVersion, $StdQParamsName)

    $text = @"
$GeneralFileHeader

using System.Management.Automation;
using gShell.Main.PowerShell.Base.v1;

using $ApiRootNamespace;
using $ApiRootNamespace.Data;

namespace gShell.$ApiNameAndVersion
{
    /// <summary> Standard Query Parameters for the $ApiName Api. </summary>
    public abstract class StandardQueryParametersBase : $StdQParamsBase
    {
$ParamAttribute
        public $StdQParamsName StandardQueryParams { get; set; }
    }
}
"@

    return $text
} 

#endregion

#region OC (Object Cmdlets)

function Write-OCMethodProperties ($SchemaObj, $Level=0) {
    
    $PositionInt = 0

    $PropertiesTexts = New-Object System.Collections.ArrayList
    
    foreach ($Property in ($SchemaObj.Properties | where {$_.Name -ne "ETag" -and $_.ShouldIncludeInTemplates -eq $true})) {
        $CommentDescription = Format-CommentString $Property.Description
        $HelpDescription = Format-HelpMessage $Property.Description
        $Type = $Property.Type
        $Name = $Property.Name
        
        $summary = Wrap-Text (Set-Indent "{%T}/// <summary> $CommentDescription </summary>" $Level)
        $attribute = Wrap-Text (Set-Indent "{%T}[Parameter(Position = $PositionInt, Mandatory = false, ValueFromPipelineByPropertyName = true, HelpMessage = `"$HelpDescription`")]" $Level)
        
        $signature = Wrap-Text (Set-Indent "{%T}public $Type $Name { get; set; }" $Level)

        $PropertyText = $summary,$attribute,$signature -join "`r`n"

        Add-String $PropertiesTexts $PropertyText

        $PositionInt++
    }

    $PropertiesTexts = $PropertiesTexts -join "`r`n`r`n"

    return $PropertiesTexts
}

function Write-OCMethod ($SchemaObj, $Level=0) {
    $Verb = "VerbsCommon.New"
    $Noun = "G" + $SchemaObj.Api.Name + $SchemaObj.Type + "Obj"
    $TypeData = $SchemaObj.TypeData
    $Type = $SchemaObj.Type
    $ClassName = "New" + $Noun + "Command"
        
    #Build out the attribute
    $attributes = "{%T}[Cmdlet($Verb, `"$Noun`",$DefaultParameterSetName SupportsShouldProcess = true)]"
    $attributes = Wrap-Text (Set-Indent $attributes $Level)

    $properties = Write-OCMethodProperties $SchemaObj -Level ($Level + 1)

    $BodyProperties = New-Object System.Collections.ArrayList

    foreach ($P in $SchemaObj.Properties) {
        Add-String $BodyProperties ("{{%T}}            {0} = this.{0}" -f $P.Name)   
    }

    $BodyPropertyAssignments = $BodyProperties -join ",`r`n"

    $body = @"
$attributes
{%T}[OutputType(typeof($TypeData))]
{%T}public class $ClassName : PSCmdlet
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {
{%T}        var body = new $TypeData()
{%T}        {
$BodyPropertyAssignments
{%T}        };

{%T}        if (ShouldProcess("$Type"))
{%T}        {
{%T}            WriteObject(body);
{%T}        }
{%T}    }
{%T}}
"@

    $body = Wrap-Text (Set-Indent $Body $Level)

    return $body
}

function Write-OCResource ($Resources) {
    foreach ($Resource in $Api.Resources) {
        
        foreach ($Child in $Resource.ChildResources) {
            Write-OCResource $Child
        }
        
        foreach ($Method in $Resource.Methods) {
              Write-OCMethod $Method
        }
    }
}

function Write-OC ($Api) {

    $SchemaCmdlets = New-Object System.Collections.ArrayList

    foreach ($SchemaObj in ($Api.SchemaObjects | Sort-Object -Property Type)) {
        $Method = Write-OCMethod $SchemaObj -Level 1
        Add-String $SchemaCmdlets $Method
    }

    $Methods = $SchemaCmdlets -join "`r`n`r`n"

    $ApiName = $Api.Name
    $ApiRootNamespace = $Api.RootNamespace

    $Text = @"
$GeneralFileHeader
using System;
using System.Collections.Generic;
using System.Management.Automation;
using Data = $ApiRootNamespace.Data;

namespace gShell.Cmdlets.$ApiName
{

$Methods

}
"@
    return $Text
}

#endregion

#region MC (Method Cmdlets)

$VerbsDict = @{
    "Add"= "VerbsCommon.Add"
    "Clear"= "VerbsCommon.Clear"
    "Close"= "VerbsCommon.Close"
    "Copy"= "VerbsCommon.Copy"
    "Enter"= "VerbsCommon.Enter"
    "Exit"= "VerbsCommon.Exit"
    "Find"= "VerbsCommon.Find"
    "Format"= "VerbsCommon.Format"
    "Get"= "VerbsCommon.Get"
    "Hide"= "VerbsCommon.Hide"
    "Join"= "VerbsCommon.Join"
    "Lock"= "VerbsCommon.Lock"
    "Move"= "VerbsCommon.Move"
    "New"= "VerbsCommon.New"
    "Open"= "VerbsCommon.Open"
    "Pop"= "VerbsCommon.Pop"
    "Push"= "VerbsCommon.Push"
    "Redo"= "VerbsCommon.Redo"
    "Remove"= "VerbsCommon.Remove"
    "Rename"= "VerbsCommon.Rename"
    "Reset"= "VerbsCommon.Reset"
    "Search"= "VerbsCommon.Search"
    "Select"= "VerbsCommon.Select"
    "Set"= "VerbsCommon.Set"
    "Show"= "VerbsCommon.Show"
    "Skip"= "VerbsCommon.Skip"
    "Split"= "VerbsCommon.Split"
    "Step"= "VerbsCommon.Step"
    "Switch"= "VerbsCommon.Switch"
    "Undo"= "VerbsCommon.Undo"
    "Unlock"= "VerbsCommon.Unlock"
    "Watch"= "VerbsCommon.Watch"

    "Connect"= "VerbsCommunications.Connect"
    "Disconnect"= "VerbsCommunications.Disconnect"
    "Read"= "VerbsCommunications.Read"
    "Receive"= "VerbsCommunications.Receive"
    "Send"= "VerbsCommunications.Send"
    "Write"= "VerbsCommunications.Write"

    "Backup"= "VerbsData.Backup"
    "Checkpoint"= "VerbsData.Checkpoint"
    "Compare"= "VerbsData.Compare"
    "Compress"= "VerbsData.Compress"
    "Convert"= "VerbsData.Convert"
    "ConvertFrom"= "VerbsData.ConvertFrom"
    "ConvertTo"= "VerbsData.ConvertTo"
    "Dismount"= "VerbsData.Dismount"
    "Edit"= "VerbsData.Edit"
    "Expand"= "VerbsData.Expand"
    "Export"= "VerbsData.Export"
    "Group"= "VerbsData.Group"
    "Import"= "VerbsData.Import"
    "Initialize"= "VerbsData.Initialize"
    "Limit"= "VerbsData.Limit"
    "Merge"= "VerbsData.Merge"
    "Mount"= "VerbsData.Mount"
    "Out"= "VerbsData.Out"
    "Publish"= "VerbsData.Publish"
    "Restore"= "VerbsData.Restore"
    "Save"= "VerbsData.Save"
    "Sync"= "VerbsData.Sync"
    "Unpublish"= "VerbsData.Unpublish"
    "Update"= "VerbsData.Update"

    "Debug"= "VerbsDiagnostic.Debug"
    "Measure"= "VerbsDiagnostic.Measure"
    "Ping"= "VerbsDiagnostic.Ping"
    "Repair"= "VerbsDiagnostic.Repair"
    "Resolve"= "VerbsDiagnostic.Resolve"
    "Test"= "VerbsDiagnostic.Test"
    "Trace"= "VerbsDiagnostic.Trace"

    "Approve"= "VerbsLifecycle.Approve"
    "Assert"= "VerbsLifecycle.Assert"
    "Complete"= "VerbsLifecycle.Complete"
    "Confirm"= "VerbsLifecycle.Confirm"
    "Deny"= "VerbsLifecycle.Deny"
    "Disable"= "VerbsLifecycle.Disable"
    "Enable"= "VerbsLifecycle.Enable"
    "Install"= "VerbsLifecycle.Install"
    "Invoke"= "VerbsLifecycle.Invoke"
    "Register"= "VerbsLifecycle.Register"
    "Request"= "VerbsLifecycle.Request"
    "Restart"= "VerbsLifecycle.Restart"
    "Resume"= "VerbsLifecycle.Resume"
    "Start"= "VerbsLifecycle.Start"
    "Stop"= "VerbsLifecycle.Stop"
    "Submit"= "VerbsLifecycle.Submit"
    "Suspend"= "VerbsLifecycle.Suspend"
    "Uninstall"= "VerbsLifecycle.Uninstall"
    "Unregister"= "VerbsLifecycle.Unregister"
    "Wait"= "VerbsLifecycle.Wait"

    "Block"= "VerbsSecurity.Block"
    "Grant"= "VerbsSecurity.Grant"
    "Protect"= "VerbsSecurity.Protect"
    "Revoke"= "VerbsSecurity.Revoke"
    "Unblock"= "VerbsSecurity.Unblock"
    "Unprotect"= "VerbsSecurity.Unprotect"

    "Use"= "VerbsOther.Use"
}

#TODO: Consolidate these two functions
function Get-McVerb ($VerbInput) {
    if ($VerbsDict.ContainsKey($VerbInput)) {
        $FullVerb = $VerbsDict[($VerbInput)]
        return $FullVerb.Split(".")[1]
    }

    return $VerbInput
}

function Get-MCAttributeVerb ($VerbInput) {
    if ($VerbsDict.ContainsKey($VerbInput)) {
        return $VerbsDict[($VerbInput)]
    }

    return "`"$VerbInput`""
}

#TODO - fix in to using list?
function Write-MCAttribute ($Method, $Noun, $DefaultParameterSet=$Null) {
    $Verb = Get-MCAttributeVerb $Method.Name
    $DocLink = $Method.Resource.Api.DiscoveryObj.documentationLink
    
    if (-not [string]::IsNullOrWhiteSpace($DefaultParameterSet)){
        $DefaultParameterSet = " DefaultParameterSetName = `"$DefaultParameterSet`","
    }

    #$DefaultParameterSetName = if ($Method.HasBodyParameter -eq $true) {
    #    " DefaultParameterSetName = `"WithBody`","
    #}

    $text = @"
[Cmdlet($Verb, "$Noun",$DefaultParameterSet SupportsShouldProcess = true, HelpUri = @"$DocLink")]
"@

    return $text
}

function Write-MCPropertyAttribute ($Mandatory, $HelpMessage, $Position, $ParameterSetName, $Level = 0) {
    $PropertiesList = New-Object System.Collections.ArrayList

    Add-String $PropertiesList ("Mandatory = $Mandatory")
    if (-not [string]::IsNullOrWhiteSpace($ParameterSetName)) {
        Add-String $PropertiesList ("ParameterSetName = `"$ParameterSetName`"")
    }
    if ($Position -ne $null) { Add-String $PropertiesList ("Position = $Position") }
    Add-String $PropertiesList "ValueFromPipelineByPropertyName = true"
    $HelpMessage = Format-HelpMessage $HelpMessage
    Add-String $PropertiesList ("HelpMessage = `"$HelpMessage`"")

    $PropertiesText = "{%T}[Parameter(" + ($PropertiesList -join ", ") + ")]"

    $PropertiesText = Wrap-Text (Set-Indent $PropertiesText $Level)

    return $PropertiesText
}

function Write-MCMediaUploadProperties($Method, $Level=0) {
    
    #expect that there are two methods and maybe a body
    $Counts = @{}
    $Counts["Media"] = @{}
    $Counts["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $Counts["NoMedia"]["WithBody"] = @(0)
        $Counts["NoMedia"]["NoBody"] = @(0)
        $Counts["Media"]["MediaWithBody"] = @(0)
        $Counts["Media"]["MediaNoBody"] = @(0)
    } else {
        $Counts["NoMedia"]["Default"] = @(0)
        $Counts["Media"]["Media"] = @(0)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $UploadParams = $Method.UploadMethod.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $ParameterTexts = New-Object System.Collections.ArrayList

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {

        $required = $Parameter.Required.ToString().ToLower()

        if ($UploadParams.Name -contains $Parameter.Name) {
            #contained in both methods
            $KeysToProcess = @("NoMedia","Media")
        } else {
            $KeysToProcess = @("NoMedia")
        }

        $Attributes = New-Object System.Collections.ArrayList
        
        #if the param exists for all param sets, don't declare any
        if ($KeysToProcess.Count -gt 1) {
            $SubKey = $Counts["NoMedia"].Keys | select -First 1
            $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level

            Add-String $Attributes $Attribute
        }
        
        #specify the param sets if needed, regardless still increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                if ($KeysToProcess.Count -eq 1) {
                    $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                        $Parameter.Description -Position $Counts[$Key][$SubKey][0] -Level $Level `
                        -ParameterSetName $SubKey

                    Add-String $Attributes $Attribute
                }
                $Counts[$Key][$SubKey][0]++
            }
        }

        $Attributes = $Attributes -join "`r`n"

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attributes,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Now add any methods from the media upload method that weren't used already
    foreach ($Parameter in $UploadParams) {

        if ($MethodParams.Name -contains $Parameter.Name `
            -and (($MethodParams | where Name -eq $Parameter.Name).Type -ne $Parameter.Type)) {
            $Parameter.Name = "MediaUpload" + $Parameter.Name
        }

        if ($MethodParams.Name -notcontains $Parameter.Name) {

            $required = $Parameter.Required.ToString().ToLower()
            
            $Attributes = New-Object System.Collections.ArrayList

            foreach ($SubKey in $Counts["Media"].Keys) {
                $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                    $Parameter.Description -Position $Counts["Media"][$SubKey][0] -Level $Level `
                    -ParameterSetName $SubKey

                Add-String $Attributes $Attribute
                $Counts["Media"][$SubKey][0]++
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
            $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

            $ParameterText = $summary,$attributes,$declaration -join "`r`n"

            Add-String $ParameterTexts $ParameterText
        }
    }

    #Handle the additional upload methods
    $PMedia = Get-MediaUploadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Get the content type property
    $Attributes = New-Object System.Collections.ArrayList
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f 'The content type for this file') $Level)
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage 'The content type for this file' `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $declaration  = wrap-text (set-indent ("{%T}public string ContentType { get; set; }") $Level)
    $ParameterText = $summary,$attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        $Attributes = New-Object System.Collections.ArrayList
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*WithBody"})) {
                $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
            ($Method.BodyParameter.Type + " Body")) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

function Write-MCMediaDownloadProperties($Method, $Level=0) {
    
    #expect that there are two methods and maybe a body
    $Counts = @{}
    $Counts["Media"] = @{}
    $Counts["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $Counts["NoMedia"]["WithBody"] = @(0)
        $Counts["NoMedia"]["NoBody"] = @(0)
        $Counts["Media"]["MediaWithBody"] = @(0)
        $Counts["Media"]["MediaNoBody"] = @(0)
    } else {
        $Counts["NoMedia"]["Default"] = @(0)
        $Counts["Media"]["Media"] = @(0)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $ParameterTexts = New-Object System.Collections.ArrayList

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {

        $required = $Parameter.Required.ToString().ToLower()

        $KeysToProcess = @("NoMedia","Media")
        
        #the params exist for all param sets, don't declare any
        $SubKey = $Counts["NoMedia"].Keys | select -First 1
        $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
            $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level
        
        #increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                $Counts[$Key][$SubKey][0]++
            }
        }

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attribute,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Handle the additional download methods
    $PMedia = Get-MediaDownloadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        $Attributes = New-Object System.Collections.ArrayList
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*WithBody"})) {
                $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
            ($Method.BodyParameter.Type + " Body")) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

#write the parameters for the cmdlet
function Write-MCProperties ($Method, $Level=0) {
    $PropertyTexts = New-Object System.Collections.ArrayList
    
    $StandardPositionInt = 0
    $BodyPositionInt = 0

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Property in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)

        $required = $Property.Required.ToString().ToLower()

        $attributes = Write-MCPropertyAttribute -Mandatory $required -HelpMessage $Property.Description `
            -Position $StandardPositionInt -Level $Level
        $signature  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Property.Type, $Property.Name) $Level)

        $PropertyText = $summary,$attributes,$signature -join "`r`n"

        $PropertyTexts.Add($PropertyText) | Out-Null
        $StandardPositionInt++
    }
    
    if ($Method.HasBodyParameter -eq $true) {
        
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)
        $signature  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
            ($Method.BodyParameter.Type + " Body")) $Level)
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Property.Description `
            -Position $StandardPositionInt -ParameterSetName "WithBody" -Level $Level
            
        $BodyText = $summary,$attribute,$signature -join "`r`n"
        $PropertyTexts.Add($BodyText) | Out-Null

        $BodyPositionInt = $StandardPositionInt
        $StandardPositionInt++

        $BodyAttributes = New-Object System.Collections.ArrayList

        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
            }

            $BPsummary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            
            $BPsignature  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            $BPAttribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage $BodyProperty.Description `
                -Position $BodyPositionInt -ParameterSetName "NoBody" -Level $Level

            $BodyPositionInt++

            $BPText = $BPSummary,$BPAttribute,$BPsignature -join "`r`n"
            $PropertyTexts.Add($BPText) | Out-Null
        }
    }

    $Text = $PropertyTexts -join "`r`n`r`n"

    return $Text
}

#writes the method parameters for within the method call
function Write-MCMethodCallParams ($Method, $Level=0, [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true){
            Add-String $Params $P.Name
        }
    }

    if ($AsMediaDownloader -eq $true) {
        $P = Get-MediaDownloadProperty $Method

        Add-String $Params $P.Name
    }

    if ($AsMediaUploader -eq $true) {
        $P = Get-MediaUploadProperty $Method

        Add-String $Params $P.Name
        Add-String $Params "ContentType"

        $MediaUploadProperties = "MediaUpload"
    }

    if (($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0) {
        $PropertiesObjectVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $MediaUploadProperties
        Add-String $Params $PropertiesObjectVarName
    }

    if ($Method.Resource.Api.CanUseServiceAccount) {
        Add-String $Params "ServiceAccount: gShellServiceAccount"
    }
    
    if ($Method.Resource.Api.HasStandardQueryParams) {
        Add-String $Params "StandardQueryParams: StandardQueryParams"
    }
    

    $result = $Params -join ", "

    return $result
}

#Write the property object in the cmdlet which creates the property object and populates the contents from the cmdlet params
function Write-MCMethodPropertiesObject ($Method, $Level=0, [bool]$AsMediaUploader) {
    if (($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0) {
        
        if ($AsMediaUploader -eq $true){
            $MediaUpload = "MediaUpload"
        }
        $PropertiesObjectVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $MediaUpload
        $PropertiesObjectFullName = "{0}.{1}.{2}{3}{4}Properties" -f `
                    ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method), `
                    $Method.Resource.Name, $Method.Name, $MediaUpload
    
        $PropertiesObjectParameters = New-Object System.Collections.ArrayList

        foreach ($P in $Method.Parameters) {
            if ($P.Required -eq $False -and $P.ShouldIncludeInTemplates -eq $true) {
                if ($AsMediaUploader) {
                    $StrippedName = $P.Name.Replace($MediaUpload, "")
                } else {
                    $StrippedName = $P.Name
                }

                Add-String $PropertiesObjectParameters ("    {0} = this.{1}" -f $StrippedName, $P.Name)
            }
        }

        $PropertiesObjectParametersText = $PropertiesObjectParameters -join ",`r`n{%T}        "

        $ParametersObj = @"
`r`n{%T}        var $PropertiesObjectVarName = new $PropertiesObjectFullName()
{%T}        {
{%T}        $PropertiesObjectParametersText
{%T}        };

"@
        $ParametersObj = Wrap-Text (Set-Indent $ParametersObj $Level)
        return $ParametersObj
    }
}

function Write-MCUploadMethod ($Method, $Level=0) {
    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
    $ParentResourceChainLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceName = $Method.Resource.Name
    
    $Verb = Get-McVerb $Method.Name
    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
    $CmdletBase = $Method.Resource.Api.Name + "Base"
    
    $MethodName = $Method.Name
    $MethodChainLower = $ParentResourceChainLower, $MethodName -join "."
    
    #Determine defeault param set name
    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
    } else {
        $DefaultParamSet = "Default"
    }

    $CmdletAttribute = Write-MCAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
    $Properties = Write-MCMediaUploadProperties $Method ($Level+1)
    $MethodCallParams = Write-MCMethodCallParams $Method
    
    if ($Method.ReturnType.Type -ne "void") {
        $WriteObjectOpen = "WriteObject("
        $WriteObjectClose = ")"
    }

    $PropertyObject = Write-MCMethodPropertiesObject $Method ($Level+2)
    $MediaPropertyObject = Write-MCMethodPropertiesObject $Method.UploadMethod ($Level+2) -AsMediaUploader $true

    $MethodCallLine = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"

    if ($Method.ReturnType.Type -ne "void") {
        $WriteObjectOpen2 = "WriteObject("
        $WriteObjectClose2 = ")"
    }

    $MediaMethodCallParams = Write-MCMethodCallParams $Method -AsMediaUploader $true

    #$P = Get-MediaUploadProperty $Method

    #$ParamSetName = $P.Name

    if ($Method.HasBodyParameter -eq $true) {
        
        $BodyProperties = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties `
            | where Name -ne "ETag"))
        {
            Add-String $BodyProperties ("{{%T}}                    {0} = this.{0}" -f $BodyProperty.Name)
        }
        $BodyProperties = $BodyProperties -join ",`r`n"

        $BodyPropertyType = $Method.BodyParameter.Type

        $BodyParameterSets = @"
{%T}            if (ParameterSetName.EndsWith("NoBody"))
{%T}            {
{%T}                Body = new $BodyPropertyType()
{%T}                {
$BodyProperties
{%T}                };
{%T}            }
"@
    }

    $text = @"
{%T}$CmdletAttribute
{%T}public class $CmdletCommand : $CmdletBase
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {
{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
{%T}        {
$BodyParameterSets
{%T}            if (ParameterSetName.StartsWith("Media"))
{%T}            {
$MediaPropertyObject
{%T}                $WriteObjectOpen2 $MethodChainLower($MediaMethodCallParams)$WriteObjectClose2;
{%T}            }
{%T}            else
{%T}            {
$PropertyObject
{%T}                $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;
{%T}            }
{%T}        }
{%T}    }
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

function Write-MCMethod ($Method, $Level=0) {
    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
    $ParentResourceChainLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceName = $Method.Resource.Name
    
    $Verb = Get-McVerb $Method.Name
    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
    $CmdletBase = $Method.Resource.Api.Name + "Base"
    
    $MethodName = $Method.Name
    $MethodChainLower = $ParentResourceChainLower, $MethodName -join "."
    
    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
    } elseif ($Method.SupportsMediaDownload) {
        $DefaultParamSet = "Default"
    }

    $CmdletAttribute = Write-MCAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
    if ($Method.HasBodyObject -eq $true) {
        $Properties = Write-MCMediaDownloadProperties $Method ($Level+1)
    } else {
        $Properties = Write-MCProperties $Method ($Level+1)
    }
    $MethodCallParams = Write-MCMethodCallParams $Method
    
    if ($Method.ReturnType.Type -ne "void") {
        $WriteObjectOpen = "WriteObject("
        $WriteObjectClose = ")"
    }

    $PropertyObject = Write-MCMethodPropertiesObject $Method $Level

    $MethodCallLine = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"

    if ($Method.HasBodyParameter -eq $true) {
        
        $BodyProperties = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties `
            | where Name -ne "ETag"))
        {
            Add-String $BodyProperties ("{{%T}}                    {0} = this.{0}" -f $BodyProperty.Name)
        }
        $BodyProperties = $BodyProperties -join ",`r`n"

        $BodyPropertyType = $Method.BodyParameter.Type

        $BodyParameterSets = @"
{%T}            if (ParameterSetName.EndsWith("NoBody"))
{%T}            {
{%T}                Body = new $BodyPropertyType()
{%T}                {
$BodyProperties
{%T}                };
{%T}            }
"@
    }

    if ($Method.SupportsMediaDownload) {
        $MediaMethodCallParams = Write-MCMethodCallParams $Method -AsMediaDownloader `
            $Method.SupportsMediaDownload

        $P = Get-MediaDownloadProperty $Method
        
        $ParamSetName = $P.Name

        $MethodCall = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"
    }
    
    $text = @"
{%T}$CmdletAttribute
{%T}public class $CmdletCommand : $CmdletBase
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {$PropertyObject
$BodyParameterSets
{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
{%T}        {
$MethodCall
{%T}        }
{%T}    }
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

function Write-MCResource ($Resource) {

    $MethodTexts = New-Object System.Collections.ArrayList
    $ParentResourceChain = Get-ParentResourceChain -MethodOrResource $Resource
    if (-not [string]::IsNullOrWhiteSpace($ParentResourceChain)) {
        $ParentResourceChain += "."
    }
    $NameSpace = "gShell.Cmdlets." + $Resource.Api.Name + "." + $ParentResourceChain + $Resource.Name

    foreach ($Method in $Resource.Methods) {
        if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {
            $MText = Write-MCUploadMethod $Method -Level 1
        } else {
            $MText = Write-MCMethod $Method -Level 1
        }

        Add-String $MethodTexts $MText
    }

    $MethodBlock = $MethodTexts -join "`r`n`r`n"

    $text = @"
namespace $NameSpace {
$MethodBlock
}
"@

    return $text
}

function Write-MCResources ($Resources) {
#should return with each resource in its own namespace at the same level?

    $ResourceTexts = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $RText = Write-MCResource $Resource
        Add-String $ResourceTexts $RText

        if ($Resource.ChildResources.Count -gt 0) {
            $ChildResourcesText = Write-MCResources $Resource.ChildResources
            Add-String $ResourceTexts $ChildResourcesText
        }
    }

    $ResourcesBlock = $ResourceTexts -join "`r`n`r`n"

    return $ResourcesBlock

}

function Write-MC ($Api) {
    
    $Resources = Write-MCResources $Api.Resources

    $ApiName = $Api.Name
    $ApiNameAndVersion = $Api.NameAndVersion

    $text = @"
$GeneralFileHeader
using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

using Google.Apis.$ApiNameAndVersion;
using Data = Google.Apis.$ApiNameAndVersion.Data;

using gShell.$ApiNameAndVersion.DotNet;

$Resources
"@

    $text = wrap-text (set-indent $text)

    return $text
}

#endregion

#region DNC (Dot Net Cmdlets -gShell.Cmdlets.[API] - wrapped method calls)

#The method signature parameters 
function Write-DNC_MethodSignatureParams ($Method, $Level=0, 
    [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader=$false, 
    [bool]$NameOnly=$false, [string]$PropertyObjNameAddition = "")
{
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true -and $P.ShouldIncludeInTemplates -eq $true){
            if ($NameOnly -ne $true) {
                Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if ($AsMediaDownloader -eq $true) {
        $P = Get-MediaDownloadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
        } else {
            Add-String $Params $P.Name
        }
    }

    if ($AsMediaUploader -eq $true) {
        $P = Get-MediaUploadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            Add-String $Params ("string ContentType")
        } else {
            Add-String $Params $P.Name
            Add-String $Params "ContentType"
        }
    }

    $ParamsForPropertyObj = $Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}

    if ($ParamsForPropertyObj -ne $null -and $ParamsForPropertyObj.Count -gt 0) {
        $PropertiesObjVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $PropertyObjNameAddition
        
        if ($NameOnly) {
            Add-String $Params $PropertiesObjVarName
        } else {
            Add-String $Params ("{0}.{1}.{2}{3}{4}Properties $PropertiesObjVarName = null" -f `
                ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method), `
                $Method.Resource.Name, $Method.Name, $PropertyObjNameAddition)
        }
    }

    if ($Method.Api.CanUseServiceAccount) {
        if ($NameOnly) {
            Add-String $Params "ServiceAccount"
        } else {
            Add-String $Params "string ServiceAccount = null"
        }
    }
    
    if ($Method.Api.HasStandardQueryParams) {
        if ($NameOnly) {
            Add-String $Params "StandardQueryParams"
        } else {
            Add-String $Params ($Method.Api.Name + "StandardQueryParameters StandardQueryParams = null")
        }
    }

    $result = $Params -join ", "

    return $result
}

##write a single wrapped method
#function Write-DNC_DownloadMethod ($Method, $Level=0) {
#    $MethodName = $Method.Name
#    
#    $PropertiesObj = Write-DNC_MethodSignatureParams $Method `
#        -AsMediaDownloader $true
#       
#    $sections = New-Object System.Collections.ArrayList
#
#    $comments = Write-DNSW_MethodComments $Method $Level
#
#    Add-String $sections (@"
#{%T}public void $MethodName ($PropertiesObj)
#{%T}{
#"@)
#
#    if ((($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0))
#    {
#        $PropertiesObjFullName = "{0}.{1}.{2}{3}Properties" -f `
#            ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method),
#            $Method.Resource.Name, $Method.Name
#        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
#        Add-String $sections "{%T}    $PropertiesObjVarName = $PropertiesObjVarName ?? new $PropertiesObjFullName();"
#    }
#
#    $ReturnProperties = Write-DNC_MethodSignatureParams $Method -NameOnly $true `
#        -AsMediaDownloader $true
#
#    $ParentResourceChain = Get-ParentResourceChain $Method -UpperCase $False
#
#    $Return = "`{{%T}}    serviceWrapper.{0}.{1}({2});" -f $ParentResourceChain, $Method.Name, $ReturnProperties
#
#    if ($Method.Parameters.Required -contains $False) {
#        $Return = "`r`n" + $Return
#    }
#
#    Add-String $sections $Return 
#
#    Add-String $sections "{%T}}"
#
#    $text = $sections -join "`r`n"
#
#    $text = $comments,$text -join "`r`n"
#
#    $text = Wrap-Text (Set-Indent $text -TabCount $Level)
#
#    return $text
#
#}
#
#write a single wrapped method
function Write-DNC_UploadMethod ($Method, $Level=0) {
    $MethodName = $Method.Name
    $MethodReturnType = $Method.ReturnType.Type
    
    $PropertiesObj = Write-DNC_MethodSignatureParams $Method `
        -AsMediaUploader $true -PropertyObjNameAddition "MediaUpload"
       
    $sections = New-Object System.Collections.ArrayList

    $comments = Write-DNSW_MethodComments $Method $Level

    Add-String $sections (@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
"@)

    if ((($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0))
    {
        $PropertiesObjFullName = "{0}.{1}.{2}{3}MediaUploadProperties" -f `
            ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method),
            $Method.Resource.Name, $Method.Name
        $PropertiesObjVarName = "{0}{1}MediaUploadProperties" -f $Method.Resource.NameLower, $Method.Name
        Add-String $sections "{%T}    $PropertiesObjVarName = $PropertiesObjVarName ?? new $PropertiesObjFullName();"
    }

    if ($Method.ReturnType.Type -ne "void") {
        $resultReturn = "return "
    }

    $ReturnProperties = Write-DNC_MethodSignatureParams $Method -NameOnly $true `
        -AsMediaUploader $true -PropertyObjNameAddition "MediaUpload"

    $ParentResourceChain = Get-ParentResourceChain $Method -UpperCase $False

    $Return = "`{{%T}}    {0}serviceWrapper.{1}.{2}({3});" -f $resultReturn, $ParentResourceChain, $Method.Name, $ReturnProperties

    if ($Method.Parameters.Required -contains $False) {
        $Return = "`r`n" + $Return
    }

    Add-String $sections $Return 

    Add-String $sections "{%T}}"

    $text = $sections -join "`r`n"

    $text = $comments,$text -join "`r`n"

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

#write a single wrapped method
function Write-DNC_Method ($Method, $Level=0, [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader=$false) {
    $MethodName = $Method.Name
    $MethodReturnType = if ($Method.HasPagedResults -eq $true) {
        "List<{0}>" -f $Method.ReturnType.Type
    } elseif ($AsMediaDownloader -eq $true) {
        "void"
    } else {
        $Method.ReturnType.Type
    }
    
    $PropertiesObj = Write-DNC_MethodSignatureParams $Method `
        -AsMediaDownloader $AsMediaDownloader -AsMediaUploader $AsMediaUploader `
       
    $sections = New-Object System.Collections.ArrayList

    $comments = Write-DNSW_MethodComments $Method $Level

    Add-String $sections (@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
"@)

    if ($Method.HasPagedResults -eq $true -or `
        (($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0))
    {

        $PropertiesObjFullName = "{0}.{1}.{2}{3}Properties" -f `
            ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method),
            $Method.Resource.Name, $Method.Name
        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
        Add-String $sections "{%T}    $PropertiesObjVarName = $PropertiesObjVarName ?? new $PropertiesObjFullName();"

        if ($Method.HasPagedResults -eq $true) {
            Add-String $sections "{%T}    $PropertiesObjVarName.StartProgressBar = StartProgressBar;"
            Add-String $sections "{%T}    $PropertiesObjVarName.UpdateProgressBar = UpdateProgressBar;"
        }
    }

    if ($Method.ReturnType.Type -ne "void" -and -not $AsMediaDownloader -eq $true) {
        $resultReturn = "return "
    }

    if ($Method.Parameters.Count -ne 0) {
        $ReturnProperties = Write-DNC_MethodSignatureParams $Method -NameOnly $true `
            -AsMediaDownloader $AsMediaDownloader -AsMediaUploader $AsMediaUploader
    }

    $ParentResourceChain = Get-ParentResourceChain $Method -UpperCase $False

    $Return = "`{{%T}}    {0}serviceWrapper.{1}.{2}({3});" -f $resultReturn, $ParentResourceChain, $Method.Name, $ReturnProperties

    if ($Method.HasPagedResults -eq $true -or $Method.Parameters.Required -contains $False) {
        $Return = "`r`n" + $Return
    }

    Add-String $sections $Return 

    Add-String $sections "{%T}}"

    $text = $sections -join "`r`n"

    $text = $comments,$text -join "`r`n"

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

#write the resources as properties for the container class
function Write-DNC_ResourcesAsProperties ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $summary = wrap-text (set-indent ("{{%T}}/// <summary> An instance of the {0} gShell dotNet resource. </summary>`r`n" -f $R.Name) $level)
        $text = "{0}{{%T}}public {1} {2} {{get; set;}}" -f $summary, $R.Name, $R.NameLower

        Add-String $list $text
    }

    $string = $list -join "`r`n`r`n"

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

#write the instantiation of the resources
function Write-DNC_ResourceInstantiations ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $text = "public {0} {1} = new {0}();" -f $R.Name, $R.NameLower

        Add-String $list $text
    }

    $string = "{%T}" + ($list -join "`r`n`r`n")

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

#write a single resource class from within the API
function Write-DNC_Resource ($Resource, $Level=0) {

    $MethodTexts = New-Object System.Collections.ArrayList

    $ResourceName = $Resource.Name 
    $ResourceNameLower = $Resource.NameLower
    
    #Handle Inner Resources
    if ($Resource.ChildResources.Count -ne 0) {
        $ChildrenProperties = Write-DNSW_ResourcesAsProperties $Resource.ChildResources -Level ($Level+1)
        $ChildResourceInstantiations = Write-DNSW_ResourceInstantiations $Resource.ChildResources -Level ($Level+2)
        $ChildResourceName = $Resource.Name
        $ChildResources = Write-DNC_Resources $Resource.ChildResources -Level ($Level+1)

        $ChildrenTextBlock = @"
{%T}#region Sub-Resources

$ChildrenProperties

{%T}public $ResourceName()
{%T}{
$ChildResourceInstantiations
{%T}}

$ChildResources

{%T}#endregion
"@

        $ChildrenTextBlock = Wrap-Text (Set-Indent $ChildrenTextBlock ($Level+1))

        Add-String $MethodTexts $ChildrenTextBlock
    }

    #Handle the methods
    foreach ($Method in $Resource.Methods) {

        #make the property object, if any
        $MethodParts = New-Object System.Collections.ArrayList
        $MethodObj = Write-DNC_Method $method ($Level+1)
        Add-String $MethodParts $MethodObj
        $MethodText = $MethodParts -join "`r`n`r`n"
        Add-String $MethodTexts $MethodText

        if ($Method.SupportsMediaDownload -eq $true) {
            $MethodObj = Write-DNC_Method $method ($Level+1) `
                -AsMediaDownloader $true
            Add-String $MethodTexts $MethodObj
        }

        if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {
            $MethodObj = Write-DNC_UploadMethod $Method.UploadMethod ($Level+1)
            Add-String $MethodTexts $MethodObj
        }
    }

    $AllMethods = $MethodTexts -join "`r`n`r`n"

    $resourceText = @"
{%T}#region $ResourceName

{%T}/// <summary> A wrapper class for the $ResourceName resource. </summary>
{%T}public class $ResourceName
{%T}{{
{0}
{%T}}}

{%T}#endregion
"@

    $resourceText = Wrap-Text (Set-Indent $resourceText $Level)

    $resourceText = $resourceText -f $AllMethods

    return $resourceText
}

#write all resources from  within  the API
function Write-DNC_Resources ($Resources, $Level=0) {
    $ResourceList = New-Object System.Collections.ArrayList
    
    foreach ($Resource in $Resources) {
        $R = Write-DNC_Resource $Resource $Level
        
        Add-String $ResourceList $R
    }

    $Text = $ResourceList -join "`r`n`r`n"

    return $Text
}

#write all sections of wrapped methods for an API
function Write-DNC ($Api, $Level=0) {

    $ApiRootNamespace = $Api.RootNamespace
    $ApiName = $Api.Name #ConvertTo-FirstUpper ($Api.DiscoveryObj.canonicalName -replace " ","")
    $ApiNameBase = $ApiName + "Base"
    $ApiNameService = $ApiName + "Service"
    $ApiVersion = $Api.DiscoveryObj.version
    $ApiNameAndVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiModuleName = $Api.RootNamespace + "." + $ApiVersionNoDots
    $ApiNameAndVersion = $Api.NameAndVersion
    $ServiceWrapperName = $Api.Name + "ServiceWrapper"
    
    $ResourcesAsProperties = Write-DNC_ResourcesAsProperties $Api.Resources -Level 2
    $ResourceInstantiatons = Write-DNSW_ResourceInstantiations $Api.Resources -Level 3
    $ResourceWrappedMethods = Write-DNC_Resources $Api.Resources -Level 2

    $baseClassType = $Api.CmdletBaseType

    $ApiInfoName = $ApiNameAndVersionNoDots + "ApiInfo"
    
    $text = @"
$GeneralFileHeader
using System;
using gShell.Main.Auth.OAuth2.v1;
using $ApiRootNamespace;
using Data = $ApiRootNamespace.Data;

namespace gShell.$ApiNameAndVersion.DotNet
{

    /// <summary>
    /// A PowerShell-ready wrapper for the $ApiName api, as well as the resources and methods therein.
    /// </summary>
    public abstract class $ApiNameBase : $baseClassType
    {

        #region Properties and Constructor

        /// <summary>The gShell dotNet class wrapper base.</summary>
        protected static $ServiceWrapperName serviceWrapper { get; set; }

        /// <summary>
        /// Required to be able to store and retrieve the serviceWrapper from the ServiceWrapperDictionary
        /// </summary>
        protected override Type serviceWrapperType { get { return typeof($ServiceWrapperName); } }

        protected override IApiInfo ApiInfo { get { return _ApiInfo; } }

        private static readonly $ApiInfoName _ApiInfo = new $ApiInfoName();

$ResourcesAsProperties

        protected $ApiNameBase()
        {
            serviceWrapper = new $ServiceWrapperName();

            ServiceWrapperDictionary[serviceWrapperType] = serviceWrapper;
            
$ResourceInstantiatons
        }
        #endregion

        #region Wrapped Methods

$ResourceWrappedMethods

        #endregion

    }
}
"@

    return $Text
}

#endregion

#region DNSW (Dot Net Service Wrapper - gShell.dotNet defining classes )

#write the resources as properties for the container class
function Write-DNSW_ResourcesAsProperties ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $summary = wrap-text (set-indent ("{{%T}}/// <summary> Gets or sets the {0} resource class. </summary>`r`n" -f $R.NameLower) $level)
        $text = "{0}{{%T}}public {1} {2} {{get; set;}}" -f $summary, $R.Name, $R.NameLower

        Add-String $list $text
    }

    $string = $list -join "`r`n`r`n"

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

#write the instantiation of the resources, used in a constructor (could be API or parent resource)
function Write-DNSW_ResourceInstantiations ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $text = "{{%T}}{0} = new {1}();" -f $R.NameLower, $R.Name

        Add-String $list $text
    }

    $string = $list -join "`r`n"

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

#the paged result block for a method
function Write-DNSW_PagedResultBlock ($Method, $Level=0) {
    $MethodReturnTypeName = $Method.ReturnType.Name
    $MethodReturnTypeFullName = $Method.ReturnType.Type

    $resultsType = $Method.ReturnType.Type

    $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name

    $text = @"
{%T}    var results = new List<$resultsType>(); 

{%T}    if (null != $PropertiesObjVarName.StartProgressBar)
{%T}    {
{%T}        $PropertiesObjVarName.StartProgressBar("Gathering $MethodReturnTypeName", string.Format("-Collecting $MethodReturnTypeName page 1"));
{%T}    }
        
{%T}    $MethodReturnTypeFullName pagedResult = request.Execute();
        
{%T}    if (pagedResult != null)
{%T}    {
{%T}        results.Add(pagedResult);
        
{%T}        while (!string.IsNullOrWhiteSpace(pagedResult.NextPageToken) && pagedResult.NextPageToken != request.PageToken && ($PropertiesObjVarName.TotalResults == 0 || results.Count < $PropertiesObjVarName.TotalResults))
{%T}        {
{%T}            request.PageToken = pagedResult.NextPageToken;
        
{%T}            if (null != $PropertiesObjVarName.UpdateProgressBar)
{%T}            {
{%T}                $PropertiesObjVarName.UpdateProgressBar(5, 10, "Gathering $MethodReturnTypeName", string.Format("-Collecting $MethodReturnTypeName page {0}", (results.Count + 1).ToString()));
{%T}            }
{%T}            pagedResult = request.Execute();
{%T}            results.Add(pagedResult);
{%T}        }
        
{%T}        if (null != $PropertiesObjVarName.UpdateProgressBar)
{%T}        {
{%T}            $PropertiesObjVarName.UpdateProgressBar(1, 2, "Gathering $MethodReturnTypeName", string.Format("-Returning {0} pages.", results.Count.ToString()));
{%T}        }
{%T}    }
        
{%T}    return results;
"@

    return $text
}

#TODO - Rename this to be more accurate to just params?
#The method signature parameters 
function Write-DNSW_MethodSignatureParams ($Method, $Level=0, [bool]$RequiredOnly=$false,
    [bool]$IncludeGshellParams=$false, [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader=$false,
    [bool]$AsUploadFileStream, [bool]$NameOnly=$false, [string]$PropertyObjNameAddition = "") {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($RequiredOnly -eq $False -or ($RequiredOnly -eq $true -and $P.Required -eq $true)){
            #skip the media downloader and media uploader properties and include later
            if ($P.CustomProperty -eq $true -or $P.ShouldIncludeInTemplates -eq $false) {
                continue
            }

            if ($NameOnly -ne $true) {
                Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if ($AsMediaDownloader -eq $true) {
        $P = Get-MediaDownloadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
        } else {
            Add-String $Params $P.Name
        }
    }

    if ($AsUploadFileStream -eq $true) {        
        if ($NameOnly -ne $true) {
            Add-String $Params ("System.IO.FileStream fileStream")
            Add-String $Params ("string ContentType")
        } else {
            Add-String $Params "fileStream"
            Add-String $Params "ContentType"
        }
    }

    if ($AsMediaUploader -eq $true) {
        $P = Get-MediaUploadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            Add-String $Params ("string ContentType")
        } else {
            Add-String $Params $P.Name
            Add-String $Params "ContentType"
        }
    }

    $ParamsForPropertyObj = $Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}

    if ($IncludeGshellParams -eq $true -and $ParamsForPropertyObj -ne $null -and $ParamsForPropertyObj.Count -gt 0) {
        $PropertiesObjVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $PropertyObjNameAddition
        
        if ($NameOnly) {
            Add-String $Params $PropertiesObjVarName
        } else {
            Add-String $Params ("{0}{1}{2}Properties $PropertiesObjVarName = null" -f $Method.Resource.Name, $Method.Name, $PropertyObjNameAddition)
        }
    }

    if ($IncludeGshellParams -eq $true -and $Method.Resource.Api.CanUseServiceAccount) {
        if ($NameOnly) {
            Add-String $Params "ServiceAccount"
        } else {
            Add-String $Params "string ServiceAccount = null"
        }
    }

    if ($IncludeGshellParams -eq $true -and $Method.Resource.Api.HasStandardQueryParams) {
        if ($NameOnly) {
            Add-String $Params "StandardQueryParams"
        } else {
            Add-String $Params ($Method.Api.Name + "StandardQueryParameters StandardQueryParams = null")
        }
    }

    $result = $Params -join ", "

    return $result
}

#The *Properties inner classes (within a resource) used to hold the non-required properties for a method
function Write-DNSW_MethodPropertyObj ($Method, $Level=0, [string]$NameAddition = "") {
    $ParamsForPropertyObj = $Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}

    if ($ParamsForPropertyObj -ne $null -and $ParamsForPropertyObj.Count -gt 0) {
    
        $Params = New-Object System.Collections.Arraylist

        foreach ($P in $ParamsForPropertyObj){

            if ($P.DiscoveryObj -ne $null -and $P.DiscoveryObj.type -eq "integer" `
                -and $P.DiscoveryObj.maximum -ne $null) {
                $InitValue = $P.DiscoveryObj.maximum
            } else {
                $InitValue = "null"
            }

            Add-String $Params (wrap-text (set-indent ("{{%T}}    /// <summary> {3} </summary>`r`n{{%T}}    public {0} {1} = {2};" `
                -f $P.Type, $P.Name, $InitValue, (Format-CommentString $P.Description)) $Level))
        }

        if ($Method.HasPagedResults -eq $true) {
            $ProgressBarString = "{%T}    /// <summary>A delegate that is used to start a progress bar.</summary>`r`n"
            $ProgressBarString += "{%T}    public Action<string, string> StartProgressBar = null;`r`n`r`n"
            $ProgressBarString += "{%T}     /// <summary>A delegate that is used to update a progress bar.</summary>`r`n"
            $ProgressBarString += "{%T}    public Action<int, int, string, string> UpdateProgressBar = null;`r`n`r`n"
            $ProgressBarString += "{%T}     /// <summary>A counter for the total number of results to pull when iterating through paged results.</summary>`r`n"
            $ProgressBarString += "{%T}    public int TotalResults = 0;"
            Add-String $Params $ProgressBarString
        }

        $pText = $Params -join "`r`n`r`n"

        $ObjName = $Method.Resource.Name + $Method.Name + $NameAddition + "Properties"

        $ObjSummary = "Optional parameters for the {0} {1} method." -f `
            $Method.Resource.Name, $Method.Name

        $Text = @"
{%T}/// <summary> $ObjSummary </summary>
{%T}public class $ObjName
{%T}{
$pText    
{%T}}
"@

        $text = wrap-text (Set-Indent -String $text -TabCount $Level)

        return $Text
    }
}

#Within a dotnet wrapped method, extracting and assigning parameters of the Method Properties object
function Write-DNSW_MethodPropertyObjAssignment ($Method, $Level=0, [string]$PropertyObjNameAddition = "") {
    $ParamsForPropertyObj = $Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}

    if ($ParamsForPropertyObj -ne $null -and $ParamsForPropertyObj.Count -gt 0) {
    
        $PropertiesObjVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $PropertyObjNameAddition

        $Params = New-Object System.Collections.ArrayList

        foreach ($P in $ParamsForPropertyObj){
            if ($P.ShouldIncludeInTemplates -eq $true) {
                Add-String $Params ("{{%T}}        request.{0} = {1}.{0};" -f $P.Name, $PropertiesObjVarName)
            }
        }

        $pText = $Params -join "`r`n"

        $Text = @"
{%T}    if ($PropertiesObjVarName != null) {
$pText
{%T}    }
"@

        $text = wrap-text (Set-Indent -String $text.ToString() -TabCount $Level)
        return $Text

    }
}

#write the xml-based comment block for a method
function Write-DNSW_MethodComments ($Method, $Level=0) {
    
    #params section
    $CommentsList = New-Object System.Collections.ArrayList
    
    $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.Description)) $Level)

    Add-String $CommentsList $summary

    foreach ($P in ($Method.Parameters | where Required -eq $true)){
        Add-String $CommentsList (wrap-text (set-indent ("{{%T}}/// <param name=`"{0}`"> {1} </param>" -f $P.Name, `
            (Format-CommentString $P.Description)) $Level))
    }

    if ($Method.Parameters.Required -contains $false) {
        Add-String $CommentsList ("{%T}/// <param name=`"Properties`"> The optional parameters for this method. </param>")
    }

    $text = $CommentsList -join "`r`n"

    return $text
}

#writes a method specifically for media downloads
function Write-DNSW_DownloadMethod ($Method, $Level=0) {
    $MethodName = $Method.Name
    $PropertiesObj = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true `
        -IncludeGshellParams $true -AsMediaDownloader $true
    $comments = Write-DNSW_MethodComments $Method $Level
    $getServiceWithServiceAccount = if ($Method.Api.CanUseServiceAccount) { "ServiceAccount" } else { $null }
    $requestParams = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -NameOnly $true
    $request = "{{%T}}    var request = GetService({0}).{1}.{2}($requestParams);" -f `
        $getServiceWithServiceAccount, `
        (Get-ParentResourceChain $Method), $Method.name

    #handle standard query params, if any
    if ($Method.Api.HasStandardQueryParams -eq $true) {
        $SQParams = New-Object System.Collections.ArrayList
        foreach ($Param in $Api.StandardQueryParams) {
            if ($Param.Type -ne $null) {
                $ParamText = "{{%T}}        request.{0} = StandardQueryParams.{1};" -f $Param.Name, $Param.NameLower
                Add-String $SQParams $ParamText
            }
        }

        $SQParamsText = $SQParams -join "`r`n"

        $SQAssignment = @"

{%T}    if (StandardQueryParams != null)
{%T}    {
$SQParamsText
{%T}    }
"@
    }

    #write the method property obj
    $PropertyAssignments = Write-DNSW_MethodPropertyObjAssignment $Method
    if (-not [string]::IsNullOrWhiteSpace($PropertyAssignments)){
        $PropertyAssignments = "`r`n" + $PropertyAssignments + "`r`n"
    }
    
    $text = @"
$comments
{%T}public void $MethodName ($PropertiesObj)
{%T}{
$request
$SQAssignment
$PropertyAssignments
{%T}    using (var fileStream = new System.IO.FileStream(DownloadPath, System.IO.FileMode.Create, System.IO.FileAccess.Write))
{%T}    {
{%T}        request.Download(fileStream);
{%T}    }
{%T}}
"@
    $text = Wrap-Text (Set-Indent $text -TabCount $Level)
    return $text
}

#writes a method specifically for media downloads
function Write-DNSW_UploadMethod ($Method, $Level=0) {
    $MethodName = $Method.Name
    $MethodReturnType = $Method.ReturnType.Type
    $MethodSignatureParameters = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true `
        -IncludeGshellParams $true -AsMediaUploader $true -PropertyObjNameAddition "MediaUpload"
    $comments = Write-DNSW_MethodComments $Method $Level
    $getServiceWithServiceAccount = if ($Method.Api.CanUseServiceAccount) { "ServiceAccount" } else { $null }
    $requestParams = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -NameOnly $true -AsUploadFileStream $true
    $request = "{{%T}}        var request = GetService({0}).{1}.{2}($requestParams);" -f `
        $getServiceWithServiceAccount, `
        (Get-ParentResourceChain $Method), $Method.name

    #handle standard query params, if any
    if ($Method.Api.HasStandardQueryParams -eq $true) {
        $SQParams = New-Object System.Collections.ArrayList
        foreach ($Param in $Api.StandardQueryParams) {
            if ($Param.Type -ne $null) {
                $ParamText = "{{%T}}            request.{0} = StandardQueryParams.{1};" -f $Param.Name, $Param.NameLower
                Add-String $SQParams $ParamText
            }
        }

        $SQParamsText = $SQParams -join "`r`n"

        $SQAssignment = @"

{%T}        if (StandardQueryParams != null)
{%T}        {
$SQParamsText
{%T}        }
"@
    }

    #write the method property obj
    $PropertyAssignments = Write-DNSW_MethodPropertyObjAssignment $Method -Level ($Level+1) -PropertyObjNameAddition "MediaUpload"
    if (-not [string]::IsNullOrWhiteSpace($PropertyAssignments)){
        $PropertyAssignments = "`r`n" + $PropertyAssignments + "`r`n"
    }
    
    $text = @"
$comments
{%T}public $MethodReturnType $MethodName ($MethodSignatureParameters)
{%T}{
{%T}    using (var fileStream = new System.IO.FileStream(SourceFilePath, System.IO.FileMode.Open))
{%T}    {
$request
$SQAssignment
$PropertyAssignments
{%T}        request.Upload();
{%T}        return request.ResponseBody;
{%T}    }
{%T}}
"@
    $text = Wrap-Text (Set-Indent $text -TabCount $Level)
    return $text
}

#write a normal (non-media up/download) single wrapped method
function Write-DNSW_Method ($Method, $Level=0) {
    $MethodName = $Method.Name
    $MethodReturnType = if ($Method.HasPagedResults -eq $true) {
        "List<{0}>" -f $Method.ReturnType.Type
    } else {
        $Method.ReturnType.Type
    }

    $PropertiesObj = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -IncludeGshellParams $true
       
    $comments = Write-DNSW_MethodComments $Method $Level

    $getServiceWithServiceAccount = if ($Method.Api.CanUseServiceAccount) { "ServiceAccount" } else { $null }
    $requestParams = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -NameOnly $true
    
    #open the request normally
    $request = "{{%T}}    var request = GetService({0}).{1}.{2}($requestParams);" -f `
        $getServiceWithServiceAccount, `
        (Get-ParentResourceChain $Method), $Method.name

    #handle standard query params, if any
    if ($Method.Api.HasStandardQueryParams -eq $true) {
        $SQParams = New-Object System.Collections.ArrayList
        foreach ($Param in $Api.StandardQueryParams) {
            if ($Param.Type -ne $null) {
                $ParamText = "{{%T}}        request.{0} = StandardQueryParams.{1};" -f $Param.Name, $Param.NameLower
                Add-String $SQParams $ParamText
            }
        }

        $SQParamsText = $SQParams -join "`r`n"

        $SQAssignment = @"

{%T}    if (StandardQueryParams != null)
{%T}    {
$SQParamsText
{%T}    }
"@
    }

    #write the method property obj
    $PropertyAssignments = Write-DNSW_MethodPropertyObjAssignment $Method -Level $Level
    if (-not [string]::IsNullOrWhiteSpace($PropertyAssignments)){
        $PropertyAssignments = "`r`n" + $PropertyAssignments + "`r`n"
    }

    if ($Method.HasPagedResults -eq $true) {
        $ResultsBlock = Write-DNSW_PagedResultBlock $Method -Level $Level
        Add-String $sections $PagedBlock
    } else {
        if ($Method.ReturnType.Type -ne "void") {
            $resultReturn = "return "
        }
        $ResultsBlock = ("{{%T}}    {0}request.Execute();" -f $resultReturn)
    }

    $text = @"
$comments
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
$request
$SQAssignment
$PropertyAssignments
$ResultsBlock
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text
    
}

#write a single resource class from within the API
function Write-DNSW_Resource ($Resource, $Level=0) {

    $MethodTexts = New-Object System.Collections.ArrayList
    
    #Handle Inner Resources
    if ($Resource.ChildResources.Count -ne 0) {
        $ChildrenProperties = Write-DNSW_ResourcesAsProperties $Resource.ChildResources -Level ($Level+1)
        $ChildResourceInstantiations = Write-DNSW_ResourceInstantiations $Resource.ChildResources -Level ($Level+2)
        $ResourceName = $Resource.Name

        $ChildrenTextBlock = @"
{%T}#region Properties and Constructor

{0}

{%T}public $ResourceName()
{%T}{{
{1}
{%T}}}

{%T}#endregion
"@

        $ChildrenTextBlock = Wrap-Text (Set-Indent $ChildrenTextBlock ($Level+1))

        $ChildrenTextBlock = $ChildrenTextBlock -f $ChildrenProperties, $ChildResourceInstantiations

        Add-String $MethodTexts $ChildrenTextBlock

        $ChildrenResources = Write-DNSW_Resources $Resource.ChildResources -Level ($Level+1)

        Add-String $MethodTexts $ChildrenResources
    }

    foreach ($Method in $Resource.Methods) {
        #make the property object, if any
        $MethodParts = New-Object System.Collections.ArrayList
        $PObj = Write-DNSW_MethodPropertyObj $method ($Level+1)
        Add-String $MethodParts $PObj
        $MethodClass = Write-DNSW_Method $Method ($Level+1)
        Add-String $MethodParts $MethodClass
        $MethodText = $MethodParts -join "`r`n`r`n"
        Add-String $MethodTexts $MethodText

        if ($Method.SupportsMediaDownload) {
            Add-String $MethodTexts (Write-DNSW_DownloadMethod -Method $Method -Level ($Level+1))
        }

        if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {
            $PObj = Write-DNSW_MethodPropertyObj $method.UploadMethod ($Level+1) -NameAddition "MediaUpload"
            $UploadMethodText = (Write-DNSW_UploadMethod -Method $Method.UploadMethod -Level ($Level+1))
            Add-String $MethodTexts (@($PObj,$UploadMethodText) -join "`r`n`r`n")
        }
    }

    $AllMethods = $MethodTexts -join "`r`n`r`n"

    $ResourceName = $Resource.Name 
    $ResourceNameLower = $Resource.NameLower

    $resourceText = @"
{%T}/// <summary> The $ResourceNameLower collection of methods. </summary>
{%T}public class $ResourceName
{%T}{{
{0}
{%T}}}
"@

    $resourceText = Wrap-Text (Set-Indent $resourceText $Level)

    $resourceText = $resourceText -f $AllMethods

    return $resourceText
}

#write all resources from  within  the API
function Write-DNSW_Resources ($Resources, $Level=0) {
    $ResourceList = New-Object System.Collections.ArrayList
    
    foreach ($Resource in $Resources) {
        $R = Write-DNSW_Resource $Resource $Level
        
        Add-String $ResourceList $R
    }

    $Text = $ResourceList -join "`r`n`r`n"

    return $Text
}

#write the entire DNSW resource file content
function Write-DNSW ($Api, $Level=0) {
    $ApiRootNamespace = $Api.RootNamespace
    $ApiName = $Api.Name #ConvertTo-FirstUpper ($Api.DiscoveryObj.canonicalName -replace " ","")
    $ApiNameService = $ApiName + "Service"
    $ApiVersion = $Api.DiscoveryObj.version
    $ApiClassNameBase = $ApiName + "Base"
    $ApiVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiModuleName = $Api.RootNamespace + "." + $ApiVersionNoDots
    $ApiNameAndVersion = $Api.NameAndVersion
    $ApiNameAndVersionWithColon = $Api.DiscoveryObj.name + ":" + $ApiVersion
    $ServiceWrapperName = $Api.Name + "ServiceWrapper"

    $ResourcesAsProperties = Write-DNSW_ResourcesAsProperties $Api.Resources -Level 2
    $ResourceInstantiatons = Write-DNSW_ResourceInstantiations $Api.Resources -Level 3
    $ResourceClasses = Write-DNSW_Resources $Api.Resources -Level 2
    
    $ApiNameAndVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiNameAndVersionColon = $ApiName + ":" + $ApiVersion
    $ApiInfoClassName = $ApiNameAndVersionNoDots + "ApiInfo"

    if ($Api.CanUseServiceAccount -eq $true)  {
        $CreateServiceServiceAccount = ", serviceAccountUser"
        $WorksWithGmail = "true"
    } else {
        $WorksWithGmail = "false"
    }
    
    $dotNetBlock = @"
$GeneralFileHeader

using $ApiRootNamespace;
using Data = $ApiRootNamespace.Data;

using gShell.Main.Apis.Services.v1;
using gShell.Main.Auth.OAuth2.v1;

namespace gShell.$ApiNameAndVersion.DotNet
{

    /// <summary>The dotNet gShell version of the $ApiName api.</summary>
    public class $ServiceWrapperName : ServiceWrapper<$ApiNameService>, IServiceWrapper<Google.Apis.Services.IClientService>
    {
        protected override bool worksWithGmail { get { return $WorksWithGmail; } }

        /// <summary>Creates a new $ApiVersion.$ApiName service.</summary>
        /// <param name="domain">The domain to which this service will be authenticated.</param>
        /// <param name="authInfo">The authenticated AuthInfo for this user and domain.</param>
        /// <param name="gShellServiceAccount">The optional email address the service account should impersonate.</param>
        protected override $ApiNameService CreateNewService(string domain, AuthenticatedUserInfo authInfo, string serviceAccountUser = null)
        {
            return new $ApiNameService(OAuth2Base.GetInitializer(domain, authInfo$CreateServiceServiceAccount));
        }

        public override IApiInfo ApiInfo { get { return _ApiInfo; } }

        private static readonly $ApiInfoClassName _ApiInfo = new $ApiInfoClassName();

        #region Properties and Constructor

$ResourcesAsProperties

        public $ServiceWrapperName()
        {
$ResourceInstantiatons
        }

        #endregion

$ResourceClasses
    }
}
"@

    return $dotNetBlock
}


#endregion

function Write-ApiSettingsCmdlets ($Api) {

    $ApiNameAndVersion = $Api.NameAndVersion
    $Noun = "G" + $Api.Name + (ConvertTo-FirstUpper $Api.Version) + "Scopes"
    $NounCommand = $Noun + "Command"
    $ApiName = $Api.Name
    $ApiVersion = $Api.Version
    $ApiNameAndVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiInfoClassName = $ApiNameAndVersionNoDots + "ApiInfo"

$SettingsText = @"
using System;
using System.Management.Automation;
using gShell.Main.Auth.OAuth2.v1;

namespace gShell.$ApiNameAndVersion
{
    [Cmdlet(VerbsCommon.Set, "$Noun",
        SupportsShouldProcess = true)]
    public class Set$NounCommand : ScopeHandlerBase
    {
        protected override IApiInfo ApiInfo { get { return _ApiInfo; } }

        private static readonly $ApiInfoClassName _ApiInfo = new $ApiInfoClassName();
        
        protected override void ProcessRecord()
        {
$ScopesBlock            

            var secrets = CheckForClientSecrets();
            if (secrets != null)
            {
                ChooseScopesAndAuthenticate(this, ApiInfo.ApiName, ApiInfo.ApiVersion, secrets, scopeInfos: ApiInfo.ScopeInfos);
            }
            else
            {
                throw new Exception(
                    "Client Secrets for $ApiNameAndVersion must be set before running cmdlets. Run 'Get-Help "
                    + "Set-$Noun' for more information.");
            }
        }
    }
}
"@

    return $SettingsText
}

function Write-ApiInfoClass ($Api) {

    $ApiName = $Api.Name
    $ApiVersion = $Api.Version
    $ApiNameAndVersion = $Api.NameAndVersion
    $ApiNameAndVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiNameAndVersionColon = $ApiName + ":" + $ApiVersion
    $ClassName = $ApiNameAndVersionNoDots + "ApiInfo"

    $Scopes = New-Object System.Collections.Arraylist

    foreach ($Scope in $Api.Scopes) {
        $ScopeString = '            new ScopeInfo("{0}", "{1}", "{2}")' -f $Scope.Name, $Scope.Description, $Scope.Uri
        Add-String -Collection $Scopes -String $ScopeString
    }

    $ScopesString = $Scopes -join ",`r`n"

    $ScopesBlockStart = "        private static readonly ScopeInfo[] _ScopeInfos = new ScopeInfo"

    if ($Scopes.Count -gt 0){ 
        $ScopesBlock = "$ScopesBlockStart[]{`r`n$ScopesString`r`n        };"
    } else {
        $ScopesBlock = "$ScopesBlockStart[0];"
    }

    if ($Api.CanUseServiceAccount -eq $true)  {
        $WorksWithGmail = "true"
    } else {
        $WorksWithGmail = "false"
    }

$ApiInfoText = @"
using gShell.Main.Auth.OAuth2.v1;

namespace gShell.$ApiNameAndVersion
{
    public sealed class $ClassName : IApiInfo
    {
        public ScopeInfo[] ScopeInfos { get { return _ScopeInfos; } }

$ScopesBlock 

        public string ApiName { get { return _ApiName; } }
        private const string _ApiName = "$ApiName";

        public string ApiVersion { get { return _ApiVersion; } }
        private const string _ApiVersion = "$ApiVersion";

        public string ApiNameAndVersion { get { return _ApiNameAndVersion; } }
        private const string _ApiNameAndVersion = "$ApiNameAndVersionColon";

        public bool WorksWithGmail { get { return $WorksWithGmail; } }
    }
}
"@

    return $ApiInfoText
}


#endregion


function Create-TemplatesFromDll ($LibraryIndex, $RestJson, $ApiName, $ApiFileVersion, $OutPath, [bool]$Log=$false) {
    Log "Loading .dll library in to Api template object" $Log
    $Api = Invoke-GShellReflection -RestJson $RestJson -ApiName $ApiName -ApiFileVersion $ApiFileVersion -LibraryIndex $LibraryIndex

    if (-not (Test-Path $OutPath)) {
        New-Item -Path $OutPath -ItemType "Directory" | Out-Null
    }

    Log "Building and writing Settings Cmdlets" $Log
    Write-ApiSettingsCmdlets $Api | Out-File ([System.IO.Path]::Combine($OutPath, "SettingsCmdlets.cs")) -Force

    Log "Building and writing ApiInfo file" $Log
    Write-ApiInfoClass $Api | Out-File ([System.IO.Path]::Combine($OutPath, "ApiInfo.cs")) -Force

    Log "Building and writing Dot Net Cmdlets" $Log
    Write-DNC $Api | Out-File ([System.IO.Path]::Combine($OutPath, "DotNetCmdlets.cs")) -Force
    
    Log "Building and writing Dot Net Service Wrapper" $Log
    Write-DNSW $Api | Out-File ([System.IO.Path]::Combine($OutPath, "DotNetServiceWrapper.cs")) -Force
    
    Log "Building and writing Method Cmdlets" $Log
    Write-MC $Api | Out-File ([System.IO.Path]::Combine($OutPath, "MethodCmdlets.cs")) -Force
    
    Log "Building and writing Object Cmdlets" $Log
    Write-OC $Api | Out-File ([System.IO.Path]::Combine($OutPath, "ObjectCmdlets.cs")) -Force

    if ($Api.HasStandardQueryParams -eq $true) {
        Log "Building and writing Standard Query Parameters" $Log
        Write-SQP $Api | Out-File ([System.IO.Path]::Combine($OutPath, "StandardQueryParameters.cs")) -Force
    
        Log "Building and writing Standard Query Parameters Base" $Log
        Write-SQPB $Api | Out-File ([System.IO.Path]::Combine($OutPath, "StandardQueryParametersBase.cs")) -Force
    }

    return $Api
}

