#TODO: make all lines return as arraylists and only join at the end to prevent having to split apart lines for wrapping and tabbing?
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
    if ($Debug) {write-host ("Calling Wrap-Text at level $Level, splitting in to {0} lines." -f $Lines.count) -ForegroundColor White -BackgroundColor Black}

    for ($l = 0; $l -lt $lines.Count; $l++){
        if ($Debug) {write-host ("Working on line:`r`n{0}" -f $lines[$l]) -ForegroundColor Cyan}

        #if the prepend text is present, make sure it's applied after whitespace - mostly for multiline comments
        if (-not [string]::IsNullOrWhiteSpace($PrependText) -and $lines[$l] -notmatch "^\s*$PrependText") {
            if ($Debug) {write-host "Adding prepend text"}
            $lines[$l] = $lines[$l].Insert(0,$PrependText)
        }

        #if padding is not in the line after whitespace, make sure it's applied - mostly for multiline comments
        if ($level -eq 0 -and $OriginalPadding -ne 0) {
            if ($Debug) {write-host "Adding in original padding"}
            $lines[$l] = $lines[$l].Insert(0,(" "*$OriginalPadding))
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

                        #$IndexOfOddQuote = $lines[$l].Substring(0,$StartInd).LastIndexOf('"')
                        #$StringSection = $lines[$l].Substring($IndexOfOddQuote+1, $StartInd-$IndexOfOddQuote-1)

                        #if ($StringSection -match $LineBreakPattern) {
                        #    #$StartInd-=2
                        #    $BreakInString = $true
                        #} else {
                        #    $StartInd = $IndexOfOddQuote
                        #}
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

#region SQP, SQPB - Standard Query Parameters Base

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

#region OC - (Object Cmdlets)

function Write-OCMethodProperties ($SchemaObj, $Level=0) {
    
    $PositionInt = 0

    $PropertiesTexts = New-Object System.Collections.ArrayList
    
    foreach ($Property in ($SchemaObj.Properties | where Name -ne "ETag")) {
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
        Add-String $BodyProperties ("{{%T}}        {0} = this.{0}" -f $P.Name)   
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
function Write-MCAttribute ($Method) {
    $Verb = Get-MCAttributeVerb $Method.Name
    $Noun = $Method.Resource.Api.Name
    $DocLink = $Method.Resource.Api.DiscoveryObj.documentationLink
    $DefaultParameterSetName = if ($Method.HasBodyParameter -eq $true) {
        " DefaultParameterSetName = `"WithBodyObject`","
    }

    $text = @"
[Cmdlet($Verb, "G$Noun",$DefaultParameterSetName SupportsShouldProcess = true, HelpUri = @"$DocLink")]
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

#write the parameters for the cmdlet
function Write-MCProperties ($Method, $Level=0) {
    $PropertyTexts = New-Object System.Collections.ArrayList
    
    $StandardPositionInt = 0
    $BodyPositionInt = 0

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Property in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body"})) {

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
            -Position $StandardPositionInt -ParameterSetName "WithBodyObject" -Level $Level
            
        $BodyText = $summary,$attribute,$signature -join "`r`n"
        $PropertyTexts.Add($BodyText) | Out-Null

        $BodyPositionInt = $StandardPositionInt
        $StandardPositionInt++

        $BodyAttributes = New-Object System.Collections.ArrayList

        foreach ($BodyProperty in ($Method.BodyParameter.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.Type + $BodyProperty.Name
            }

            $BPsummary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            
            $BPsignature  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            $BPAttribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage $BodyProperty.Description `
                -Position $BodyPositionInt -ParameterSetName "NoBodyObject" -Level $Level

            $BodyPositionInt++

            $BPText = $BPSummary,$BPAttribute,$BPsignature -join "`r`n"
            $PropertyTexts.Add($BPText) | Out-Null
        }
    }

    $Text = $PropertyTexts -join "`r`n`r`n"

    #$text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $Text
}

#writes the method parameters for within the method call
function Write-MCMethodCallParams ($Method, $Level=0) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true){
            if ($P.Name -eq "Body") {
                Add-String $Params "Body"
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if  ($Method.Parameters.Required -contains $False) {
        $PropertiesObjectVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
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
function Write-MCMethodPropertiesObject ($Method, $Level=0) {
    if ($Method.Parameters.Required -contains $False) {
        
        $PropertiesObjectVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
        $PropertiesObjectFullName = "{0}.{1}.{2}{3}Properties" -f `
                    ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method), `
                    $Method.Resource.Name, $Method.Name
    
        $PropertiesObjectParameters = New-Object System.Collections.ArrayList

        foreach ($P in $Method.Parameters) {
            if ($P.Required -eq $False) {
                Add-String $PropertiesObjectParameters ("{{%T}}        {0} = this.{0}" -f $P.Name)
            }
        }

        $PropertiesObjectParametersText = $PropertiesObjectParameters -join ",`r`n{%T}        "

        $ParametersObj = @"
`r`n{%T}        var $PropertiesObjectVarName = new $PropertiesObjectFullName()
{%T}        {
{%T}        $PropertiesObjectParametersText
{%T}        };

"@

        return $ParametersObj
    }
}

function Write-MCMethod ($Method, $Level=0) {
    $ResourceParent = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceParentLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceName = $Method.Resource.Name
    
    $Verb = Get-McVerb $Method.Name
    $Noun = "G" + $Method.Resource.Api.Name + $ResourceName
    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
    $CmdletBase = $Method.Resource.Api.Name + "Base"
    
    $MethodName = $Method.Name
    $MethodChainLower = $ResourceParentLower, $MethodName -join "."
    
    $CmdletAttribute = Write-MCAttribute $Method
    $Properties = Write-MCProperties $Method ($Level+1)
    $MethodCallParams = Write-MCMethodCallParams $Method
    
    $WriteObjectOpen = if ($Method.ReturnType.Type -ne "void") { "WriteObject(" }
    $WriteObjectClose = if ($Method.ReturnType.Type -ne "void") { ")" }

    $PropertyObject = Write-MCMethodPropertiesObject $Method $Level
    
    $text = @"
{%T}$CmdletAttribute
{%T}public class $CmdletCommand : $CmdletBase
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {$PropertyObject
{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
{%T}        {
{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;
{%T}        }
{%T}    }
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

function Write-MCResource ($Resource) {

    $MethodTexts = New-Object System.Collections.ArrayList
    $ApiName = $Resource.Api.Name

    foreach ($Method in $Resource.Methods) {
        $MText = Write-MCMethod $Method -Level 0
        Add-String $MethodTexts $MText
    }

    $MethodBlock = $MethodTexts -join "`r`n`r`n"

    $text = @"
namespace gShell.Cmdlets.$ApiName {
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


#region gShell.Cmdlets.[API] - wrapped method calls (DNC - Dot Net Cmdlets)

#The method signature parameters 
function Write-DNC_MethodSignatureParams ($Method, $Level=0, [bool]$NameOnly=$false) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true){
            if ($NameOnly -ne $true) {
                Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if  ($Method.Parameters.Required -contains $False) {
        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
        
        if ($NameOnly) {
            Add-String $Params $PropertiesObjVarName
        } else {
            Add-String $Params ("{0}.{1}.{2}{3}Properties $PropertiesObjVarName = null" -f `
                ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method), `
                $Method.Resource.Name, $Method.Name)
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

#write a single wrapped method
function Write-DNC_Method ($Method, $Level=0) {
    $MethodName = $Method.Name
    $MethodReturnType = if ($Method.HasPagedResults -eq $true) {
        "List<{0}>" -f $Method.ReturnType.Type
    } else {
        $Method.ReturnType.Type
    }

    $PropertiesObj = if ($Method.Parameters.Count -ne 0) {
        Write-DNC_MethodSignatureParams $Method
    }
       
    $sections = New-Object System.Collections.ArrayList

    $comments = Write-DNSW_MethodComments $Method $Level

    Add-String $sections (@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
"@)

    if ($Method.HasPagedResults -eq $true -or $Method.Parameters.Required -contains $False) {
        $PropertiesObjFullName = "{0}.{1}.{2}{3}Properties" -f `
            ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method),
            $Method.Resource.Name, $Method.Name
        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
        Add-String $sections "{%T}    $PropertiesObjVarName = $PropertiesObjVarName ?? new $PropertiesObjFullName();"
    }

    if ($Method.HasPagedResults -eq $true) {
        Add-String $sections "{%T}    $PropertiesObjVarName.StartProgressBar = StartProgressBar;"
        Add-String $sections "{%T}    $PropertiesObjVarName.UpdateProgressBar = UpdateProgressBar;"
    }

    if ($Method.ReturnType.Type -ne "void") {
        $resultReturn = "return "
    }

    $ReturnProperties = if ($Method.Parameters.Count -ne 0) {
        Write-DNC_MethodSignatureParams $Method  -NameOnly $true
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
    $ApiVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiModuleName = $Api.RootNamespace + "." + $ApiVersionNoDots
    $ApiNameAndVersion = $Api.NameAndVersion
    $ServiceWrapperName = $Api.Name + "ServiceWrapper"
    
    $ResourcesAsProperties = Write-DNC_ResourcesAsProperties $Api.Resources -Level 2
    $ResourceInstantiatons = Write-DNSW_ResourceInstantiations $Api.Resources -Level 3
    $ResourceWrappedMethods = Write-DNC_Resources $Api.Resources -Level 2

    $baseClassType = $Api.CmdletBaseType
    #if (-not (Has-ObjProperty $Api.DiscoveryObj "auth")){ #discovery API
    #    "OAuth2CmdletBase"
    #} elseif (-not ($Api.RootNamespace.StartsWith("Google.Apis.admin"))) {
    #    "ServiceAccountCmdletBase"
    #} elseif ((Has-ObjProperty $Api.DiscoveryObj "parameters")) {
    #    "StandardParamsCmdletBase"
    #} else {
    #    "AuthenticatedCmdletBase"
    #}

    $text = @"
$GeneralFileHeader
using System;
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


#region gShell.dotNet - defining classes (DNSW - Dot Net Service Wrapper)

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

#The method signature parameters 
function Write-DNSW_MethodSignatureParams ($Method, $Level=0, [bool]$RequiredOnly=$false,
    [bool]$IncludeGshellParams=$false, [bool]$NameOnly=$false) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($RequiredOnly -eq $False -or ($RequiredOnly -eq $true -and $P.Required -eq $true)){
            if ($NameOnly -ne $true) {
                Add-String $Params ("{0} {1}" -f $P.Type, $P.Name)
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if ($IncludeGshellParams -eq $true -and $Method.Parameters.Required -contains $False) {
        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name
        
        if ($NameOnly) {
            Add-String $Params $PropertiesObjVarName
        } else {
            Add-String $Params ("{0}{1}Properties $PropertiesObjVarName = null" -f $Method.Resource.Name, $Method.Name)
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
function Write-DNSW_MethodPropertyObj ($Method, $Level=0) {
    if ($Method.Parameters.Required -contains $false) {
    
        $Params = New-Object System.Collections.Arraylist

        foreach ($P in ($Method.Parameters | where Required -eq $False)){

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

        $ObjName = $Method.Resource.Name + $Method.Name + "Properties"

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
function Write-DNSW_MethodPropertyObjAssignment ($Method, $Level=0) {
    if ($Method.Parameters.Required -contains $false) {
    
        $PropertiesObjVarName = "{0}{1}Properties" -f $Method.Resource.NameLower, $Method.Name

        $Params = New-Object System.Collections.ArrayList

        foreach ($P in ($Method.Parameters | where Required -eq $False)){
            if ($P.Type -ne $null) {
                Add-String $Params ("{{%T}}        request.{0} = {1}.{0};" -f $P.Name, $PropertiesObjVarName)
            }
        }

        $pText = $Params -join "`r`n"

        $Text = @"
{%T}    if ($PropertiesObjVarName != null) {
$pText
{%T}    }
"@
        return $Text.ToString()

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

#write a single wrapped method
function Write-DNSW_Method ($Method, $Level=0) {
    $MethodName = $Method.Name
    $MethodReturnType = if ($Method.HasPagedResults -eq $true) {
        "List<{0}>" -f $Method.ReturnType.Type
    } else {
        $Method.ReturnType.Type
    }

    $PropertiesObj = if ($Method.Parameters.Count -ne 0) {
        Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -IncludeGshellParams $true -IncludePropertiesObject $true
    }
       
    $sections = New-Object System.Collections.ArrayList

    $comments = Write-DNSW_MethodComments $Method $Level

    $requestParams = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -NameOnly $true

    $getServiceWithServiceAccount = if ($Method.Api.CanUseServiceAccount) { "ServiceAccount" } else { $null }

    $request = "var request = GetService({0}).{1}.{2}($requestParams);" -f `
        $getServiceWithServiceAccount, `
        (Get-ParentResourceChain $Method), $Method.name

    if ($Method.Api.HasStandardQueryParams) {
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

        $SQAssignment = wrap-text (set-indent $SQAssignment $Level)
    }

    Add-String $sections (@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
{%T}    $request

$SQAssignment
"@)

    $PropertyAssignments = Write-DNSW_MethodPropertyObjAssignment $Method
    if ($PropertyAssignments -ne $null) {Add-String $sections $PropertyAssignments}

    if ($Method.HasPagedResults) {
        $PagedBlock = Write-DNSW_PagedResultBlock $Method -Level $Level
        Add-String $sections $PagedBlock
    } else {
        if ($Method.ReturnType.Type -ne "void") {
            $resultReturn = "return "
        }
        Add-String $sections ("{{%T}}    {0}request.Execute();" -f $resultReturn)
    }

    Add-String $sections "{%T}}"

    $text = $sections -join "`r`n`r`n"

    $text = $comments,$text -join "`r`n"

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text
    
}

#TODO this not used?
#write all wrapped methods in a resource
function Write-DNSW_Methods ($Resource, $Level=0) {
    $list = New-Object System.Collections.ArrayList

    $ResourceName = $Resource.Name
    
    foreach ($M in $Resource.Methods) {
        $text = Write-DNSW_Method $M

        Add-String $list $text
    }

    $string = $list -join "`r`n`r`n"

    $string = wrap-text (Set-Indent -String $string -TabCount $Level)
    
    return $string
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

        #Make the method class
        $MethodClass = Write-DNSW_Method $Method ($Level+1)

        Add-String $MethodParts $MethodClass

        $MethodText = $MethodParts -join "`r`n`r`n"

        Add-String $MethodTexts $MethodText
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
function Write-DNSW ($Resource, $Level=0) {
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
    
    if ($Resource.Api.CanUseServiceAccount -eq $true)  {
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

        /// <summary>Returns the api name and version in {name}:{version} format.</summary>
        public override string apiNameAndVersion { get { return "$ApiNameAndVersionWithColon"; } }

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


#endregion


function Create-TemplatesFromDll ($LibraryIndex, $RestJson, $ApiName, $ApiFileVersion, $OutPath, [bool]$Log=$false) {
    Log "Loading .dll library in to Api template object" $Log
    $Api = Invoke-GShellReflection -RestJson $RestJson -ApiName $ApiName -ApiFileVersion $ApiFileVersion -LibraryIndex $LibraryIndex

    if (-not (Test-Path $OutPath)) {
        New-Item -Path $OutPath -ItemType "Directory" | Out-Null
    }

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
