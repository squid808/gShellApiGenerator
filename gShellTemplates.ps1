﻿#TODO: make all lines return as arraylists and only join at the end to prevent having to split apart lines for wrapping and tabbing?
#TODO: make each write method take in an [indent] level param to determine indents, and handle tabbing and wrapping before returning?
#TODO: incorporate set-indent and wrap-text?
#TODO: determine impact of ApiVersionNoDots on APIs that have underscores already - what are their namespaces?
#TODO: fix indenting in middle of quote

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
function Wrap-Text ($Text, $Level=0, $Padding=0, $PrependText=$null) {
    $lines =  $Text -split "`r`n"

    for ($l = 0; $l -lt $lines.Count; $l++){
        if ($lines[$l].Length -gt 120) {
            $StartInd = 119
            
            if ((Get-CharCountInString $lines[$l].Substring(0,$StartInd) '"')%2 -eq 1){
                $StartInd = $lines[$l].Substring(0,$StartInd).LastIndexOf('"')
            }

            for ($i = $StartInd; $i -ge 0; $i--) {
                if ($lines[$l][$i] -match "[ \)\],]") {
                    $matches = $null
                    if ($Level -eq 0) {
                        if ($lines[$l] -match "[^\s]") {
                            $padding = $lines[$l].IndexOf($matches[0])
                        } else {
                            $padding = 0
                        }
                    }

                    if ($lines[$l] -match "///\s") {
                        $lines[$l] = $lines[$l].Insert(($i+1), 
                        ("`r`n{0}///  " -f (" "*$padding)))
                    } else {
                        $lines[$l] = $lines[$l].Insert(($i+1), 
                        ("`r`n$PrependText{0}    " -f (" "*$padding)))
                    }

                    $lines[$l] = Wrap-Text $lines[$l] -Level ($Level+1) -Padding $padding
                    break;
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

function Get-ParentResourceChain ($Method, $JoinChar = ".") {
    #TODO!
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

#region ObjCmdlets - 

#endregion


#region Cmdlets

#endregion


#region gShell.Cmdlets.[API] - wrapped method calls (DNC - Dot Net Cmdlets)

#The method signature parameters 
function Write-DNC_MethodSignatureParams ($Method, $Level=0, [bool]$NameOnly=$false) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true){
            if ($NameOnly -ne $true) {
                $Params.Add(("{0} {1}" -f $P.Type, $P.Name)) | Out-Null
            } else {
                $Params.Add($P.Name) | Out-Null
            }
        }
    }

    if  ($Method.Parameters.Required -contains $False) {
        if ($NameOnly) {
            $Params.Add(("Properties")) | Out-Null
        } else {
            $Params.Add(("g{0}.{1}.{2}{3}Properties Properties = null" -f $Method.Resource.Api.Name, $Method.Resource.Name, `
                $Method.Resource.Name, $Method.Name)) | Out-Null
        }
    }

    if ($NameOnly) {
        $Params.Add("StandardQueryParams") | Out-Null
    } else {
        $Params.Add("StandardQueryParameters StandardQueryParams = null") | Out-Null
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

    $sections.Add((@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
"@)) | Out-Null

    if ($Method.HasPagedResults -eq $true -or $Method.Parameters.Required -contains $False) {
        $PropertiesObjFullName = "g{0}.{1}.{1}{2}Properties" -f (ConvertTo-FirstUpper ($Api.DiscoveryObj.canonicalName -replace " ","")),
            $Method.Resource.Name, $Method.Name
        $sections.Add("{%T}    Properties = Properties ?? new $PropertiesObjFullName();") | Out-Null
    }

    if ($Method.HasPagedResults -eq $true) {
        $sections.Add("{%T}    Properties.StartProgressBar = StartProgressBar;") | Out-Null
        $sections.Add("{%T}    Properties.UpdateProgressBar = UpdateProgressBar;") | Out-Null
    }

    if ($Method.ReturnType.Type -ne "void") {
        $resultReturn = "return "
    }

    $ReturnProperties = if ($Method.Parameters.Count -ne 0) {
        Write-DNC_MethodSignatureParams $Method  -NameOnly $true
    }

    $ParentResourcePath = 

    $Return = "`{{%T}}    {0}mainBase.{1}.{2}({3});" -f $resultReturn, $method.Resource.NameLower, $Method.Name, $ReturnProperties

    if ($Method.HasPagedResults -eq $true -or $Method.Parameters.Required -contains $False) {
        $Return = "`r`n" + $Return
    }

    $sections.Add($Return) | Out-Null

    $sections.Add("{%T}}") | Out-Null

    $text = $sections -join "`r`n"

    $text = $comments,$text -join "`r`n"

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

#write the resources as properties for the container class
function Write-DNC_ResourcesAsProperties ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $summary = "{{%T}}/// <summary> An instance of the {0} gShell dotNet resource. </summary>`r`n" -f $R.Name
        $text = "{0}{{%T}}public {1} {2} {{get; set;}}" -f $summary, $R.Name, $R.NameLower

        $list.Add($text) | Out-Null
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

        $list.Add($text) | Out-Null
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

        $MethodTexts.Add($ChildrenTextBlock) | Out-Null
    }

    #Handle the methods
    foreach ($Method in $Resource.Methods) {

        #make the property object, if any
        $MethodParts = New-Object System.Collections.ArrayList
        
        $MethodObj = Write-DNC_Method $method ($Level+1)
        
        if ($MethodObj -ne $null) {
            $MethodParts.Add($MethodObj) | Out-Null
        }

        $MethodText = $MethodParts -join "`r`n`r`n"

        if ($MethodText -ne $null) {
            $MethodTexts.Add($MethodText) | Out-Null
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
        
        if ($R -ne $null) {
            $ResourceList.Add($R) | Out-Null
        }
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
    $ApiNameAndVersion = $Api.DiscoveryObj.name + ":" + $ApiVersion
    
    $ResourcesAsProperties = Write-DNC_ResourcesAsProperties $Api.Resources -Level 2
    $ResourceInstantiatons = Write-DNSW_ResourceInstantiations $Api.Resources -Level 3
    $ResourceWrappedMethods = Write-DNC_Resources $Api.Resources -Level 2

    $text = @"
$GeneralFileHeader
using gShell.Cmdlets.Utilities.OAuth2;
using gShell.dotNet;
using gShell.dotNet.Utilities.OAuth2;

using System;
using System.Collections.Generic;
//using System.Management.Automation;
//
//using Google.Apis.Auth.OAuth2;
//using Google.Apis.Services;
using $ApiRootNamespace;
using Data = $ApiRootNamespace.Data;
//
//using gShell.dotNet.Utilities;
//using gShell.dotNet.Utilities.OAuth2;
using g$ApiName = gShell.dotNet.$ApiName;

namespace gShell.Cmdlets.$ApiName {

    

    /// <summary>
    /// A PowerShell-ready wrapper for the $ApiName api, as well as the resources and methods therein.
    /// </summary>
    public abstract class $ApiNameBase : StandardParamsCmdletBase
    {

        #region Properties and Constructor

        /// <summary>The gShell dotNet class wrapper base.</summary>
        protected static g$ApiName mainBase { get; set; }

        /// <summary>
        /// Required to be able to store and retrieve the mainBase from the ServiceWrapperDictionary
        /// </summary>
        protected override Type mainBaseType { get { return typeof(g$ApiName); } }

$ResourcesAsProperties

        protected $ApiNameBase()
        {
            mainBase = new g$ApiName();

            ServiceWrapperDictionary[mainBaseType] = mainBase;
            
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

        $summary = "{{%T}}/// <summary> Gets or sets the {0} resource class. </summary>`r`n" -f $R.NameLower
        $text = "{0}{{%T}}public {1} {2} {{get; set;}}" -f $summary, $R.Name, $R.NameLower

        $list.Add($text) | Out-Null
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

        $list.Add($text) | Out-Null
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

    $text = @"
{%T}    var results = new List<$resultsType>(); 

{%T}    if (null != Properties.StartProgressBar)
{%T}    {
{%T}        Properties.StartProgressBar("Gathering $MethodReturnTypeName", string.Format("-Collecting $MethodReturnTypeName page 1"));
{%T}    }
        
{%T}    $MethodReturnTypeFullName pagedResult = request.Execute();
        
{%T}    if (pagedResult != null)
{%T}    {
{%T}        results.Add(pagedResult);
        
{%T}        while (!string.IsNullOrWhiteSpace(pagedResult.NextPageToken) && pagedResult.NextPageToken != request.PageToken && (Properties.TotalResults == 0 || results.Count < Properties.TotalResults))
{%T}        {
{%T}            request.PageToken = pagedResult.NextPageToken;
        
{%T}            if (null != Properties.UpdateProgressBar)
{%T}            {
{%T}                Properties.UpdateProgressBar(5, 10, "Gathering $MethodReturnTypeName", string.Format("-Collecting $MethodReturnTypeName page {0}", (results.Count + 1).ToString()));
{%T}            }
{%T}            pagedResult = request.Execute();
{%T}            results.Add(pagedResult);
{%T}        }
        
{%T}        if (null != Properties.UpdateProgressBar)
{%T}        {
{%T}            Properties.UpdateProgressBar(1, 2, "Gathering $MethodReturnTypeName", string.Format("-Returning {0} pages.", results.Count.ToString()));
{%T}        }
{%T}    }
        
{%T}    return results;
"@

    return $text
}

#The method signature parameters 
function Write-DNSW_MethodSignatureParams ($Method, $Level=0, [bool]$RequiredOnly=$false,
    [bool]$IncludeStandardQueryParams=$false, [bool]$IncludePropertiesObject=$false, [bool]$NameOnly=$false) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($RequiredOnly -eq $False -or ($RequiredOnly -eq $true -and $P.Required -eq $true)){
            if ($NameOnly -ne $true) {
                $Params.Add(("{0} {1}" -f $P.Type, $P.Name)) | Out-Null
            } else {
                $Params.Add($P.Name) | Out-Null
            }
        }
    }

    if ($IncludePropertiesObject -eq $true -and $Method.Parameters.Required -contains $False) {
        if ($NameOnly) {
            $Params.Add(("Properties")) | Out-Null
        } else {
            $Params.Add(("{0}{1}Properties Properties = null" -f $Method.Resource.Name, $Method.Name)) | Out-Null
        }
    }

    if ($IncludeStandardQueryParams -eq $true) {
        if ($NameOnly) {
            $Params.Add("StandardQueryParams") | Out-Null
        } else {
            $Params.Add("StandardQueryParameters StandardQueryParams = null") | Out-Null
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

            $Params.Add(("{{%T}}    /// <summary> {3} </summary>`r`n{{%T}}    public {0} {1} = {2};" `
                -f $P.Type, $P.Name, $InitValue,  $P.Description)) | Out-Null
        }

        if ($Method.HasPagedResults -eq $true) {
            $ProgressBarString = "{%T}    /// <summary>A delegate that is used to start a progress bar.</summary>`r`n"
            $ProgressBarString += "{%T}    public Action<string, string> StartProgressBar = null;`r`n`r`n"
            $ProgressBarString += "{%T}     /// <summary>A delegate that is used to update a progress bar.</summary>`r`n"
            $ProgressBarString += "{%T}    public Action<int, int, string, string> UpdateProgressBar = null;`r`n`r`n"
            $ProgressBarString += "{%T}     /// <summary>A counter for the total number of results to pull when iterating through paged results.</summary>`r`n"
            $ProgressBarString += "{%T}    public int TotalResults = 0;"
            $Params.Add($ProgressBarString) | Out-Null
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
    
        $Params = New-Object System.Collections.ArrayList

        foreach ($P in ($Method.Parameters | where Required -eq $False)){
            $Params.Add(("{{%T}}        request.{0} = Properties.{0};" -f $P.Name)) | Out-Null
        }

        $pText = $Params -join "`r`n"

        $Text = @"
{%T}    if (Properties != null) {
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
    
    $summary = "{{%T}}/// <summary> {0} </summary>" -f $Method.Description

    $CommentsList.Add($summary) | Out-Null

    foreach ($P in ($Method.Parameters | where Required -eq $true)){
        $CommentsList.Add(("{{%T}}/// <param name=`"{0}`"> {1} </param>" -f $P.Name, $P.Description)) | Out-Null
    }

    if ($Method.Parameters.Required -contains $false) {
        $CommentsList.Add(("{%T}/// <param name=`"Properties`"> The optional parameters for this method. </param>")) | Out-Null
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
        Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -IncludeStandardQueryParams $true -IncludePropertiesObject $true
    }
       
    $sections = New-Object System.Collections.ArrayList

    $comments = Write-DNSW_MethodComments $Method $Level

    $requestParams = Write-DNSW_MethodSignatureParams $Method -RequiredOnly $true -NameOnly $true

    $request = "var request = GetService().{0}.{1}($requestParams);" -f $Method.Resource.Name, $Method.name

    $sections.Add((@"
{%T}public $MethodReturnType $MethodName ($PropertiesObj)
{%T}{
{%T}    $request

{%T}    if (StandardQueryParams != null) {
{%T}        request.Fields = StandardQueryParams.fields;
{%T}        request.QuotaUser = StandardQueryParams.quotaUser;
{%T}        request.UserIp = StandardQueryParams.userIp;
{%T}    }
"@)) | Out-Null

    $PropertyAssignments = Write-DNSW_MethodPropertyObjAssignment $Method
    if ($PropertyAssignments -ne $null) {$sections.Add($PropertyAssignments) | Out-Null}

    if ($Method.HasPagedResults) {
        $PagedBlock = Write-DNSW_PagedResultBlock $Method -Level $Level
        $sections.Add($PagedBlock) | Out-Null
    } else {
        if ($Method.ReturnType.Type -ne "void") {
            $resultReturn = "return "
        }
        $sections.Add(("{{%T}}    {0}request.Execute();" -f $resultReturn)) | Out-Null
    }

    $sections.Add("{%T}}") | Out-Null

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

        $list.Add($text) | Out-Null
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

        $MethodTexts.Add($ChildrenTextBlock) | Out-Null

        $ChildrenResources = Write-DNSW_Resources $Resource.ChildResources -Level ($Level+1)

        $MethodTexts.Add($ChildrenResources) | Out-Null
    }

    foreach ($Method in $Resource.Methods) {
        #make the property object, if any
        $MethodParts = New-Object System.Collections.ArrayList
        
        $PObj = Write-DNSW_MethodPropertyObj $method ($Level+1)
        
        if ($PObj -ne $null) {
            $MethodParts.Add($PObj) | Out-Null
        }

        #Make the method class
        $MethodClass = Write-DNSW_Method $Method ($Level+1)

        $MethodParts.Add($MethodClass) | Out-Null

        $MethodText = $MethodParts -join "`r`n`r`n"

        if ($MethodText -ne $null) {
            $MethodTexts.Add($MethodText) | Out-Null
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
        
        if ($R -ne $null) {
            $ResourceList.Add($R) | Out-Null
        }
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
    $ApiNameAndVersion = $Api.DiscoveryObj.name + ":" + $ApiVersion

    $ResourcesAsProperties = Write-DNSW_ResourcesAsProperties $Api.Resources -Level 2
    $ResourceInstantiatons = Write-DNSW_ResourceInstantiations $Api.Resources -Level 3
    $ResourceClasses = Write-DNSW_Resources $Api.Resources -Level 2
    
    #TODO: figure out service account
    if ($Api.Name -eq "Admin") {
        $UseServiceAccount = $false
        $WorksWithGmail = "false"
    } else {
        $UseServiceAccount = $true
        $WorksWithGmail = "true"
    }

    if ($UseServiceAccount)  {
        $CreateServiceServiceAccountSignature = ", string gShellServiceAccount = null"
        $CreateServiceServiceAccount = ", gShellServiceAccount"
    }
    
    $dotNetBlock = @"
$GeneralFileHeader

#using System;
#using System.Collections.Generic;
#
#using gShell.dotNet;
#using gShell.dotNet.Utilities.OAuth2;
#
#using $ApiRootNamespace;
#using Data = $ApiRootNamespace.Data;

namespace gShell.dotNet
{

    /// <summary>The dotNet gShell version of the $ApiName api.</summary>
    public class $ApiName : ServiceWrapper<$ApiNameService>, IServiceWrapper<Google.Apis.Services.IClientService>
    {
        protected override bool worksWithGmail { get { return $WorksWithGmail; } }

        /// <summary>Creates a new $ApiVersion.$ApiName service.</summary>
        /// <param name="domain">The domain to which this service will be authenticated.</param>
        /// <param name="authInfo">The authenticated AuthInfo for this user and domain.</param>
        /// <param name="gShellServiceAccount">The optional email address the service account should impersonate.</param>
        protected override $ApiNameService CreateNewService(string domain, AuthenticatedUserInfo authInfo$CreateServiceServiceAccountSignature)
        {
            return new $ApiNameService(OAuth2Base.GetInitializer(domain, authInfo$CreateServiceServiceAccount));
        }

        /// <summary>Returns the api name and version in {name}:{version} format.</summary>
        public override string apiNameAndVersion { get { return "$ApiNameAndVersion"; } }

        #region Properties and Constructor

$ResourcesAsProperties

        public $ApiName()
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



$RestJson = Load-RestJsonFile admin directory_v1
#$RestJson = Load-RestJsonFile admin reports_v1
#$RestJson = Load-RestJsonFile discovery v1
#$RestJson = Load-RestJsonFile gmail v1

$LibraryIndex = Get-JsonIndex $LibraryIndexRoot
$Api = Invoke-GShellReflection $RestJson $LibraryIndex

$Resources = $Api.Resources
$Resource = $Resources[0]
$Methods = $Resource.Methods
$Method = $Methods[1]
$M = $Method

((write-dnc $Api) + "`r`n`r`n`r`n`r`n" + (write-dnsw $Api) ) | Out-File $env:USERPROFILE\Documents\gShell\gShell\gShell\dotNet\Directory\Google.Apis.admin.Directory.directory_v1_gshell_dotnet.cs -Force