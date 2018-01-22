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
    $P.Type = New-BasicTypeStruct string
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
    $P.Type = New-BasicTypeStruct string
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