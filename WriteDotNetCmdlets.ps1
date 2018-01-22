#The method signature parameters 
function Write-DNC_MethodSignatureParams ($Method, $Level=0, 
    [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader=$false, 
    [bool]$NameOnly=$false, [string]$PropertyObjNameAddition = "")
{
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true -and $P.ShouldIncludeInTemplates -eq $true){
            if ($NameOnly -ne $true) {
                Add-String $Params ("{0} {1}" -f $P.Type.Type, $P.Name)
            } else {
                Add-String $Params $P.Name
            }
        }
    }

    if ($AsMediaDownloader -eq $true) {
        $P = Get-MediaDownloadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type.Type, $P.Name)
        } else {
            Add-String $Params $P.Name
        }
    }

    if ($AsMediaUploader -eq $true) {
        $P = Get-MediaUploadProperty ($Method)
        
        if ($NameOnly -ne $true) {
            Add-String $Params ("{0} {1}" -f $P.Type.Type, $P.Name)
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
    $MethodReturnType = $Method.ReturnType.Type.Type
    
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

    if ($Method.ReturnType.Type.Type -ne "void") {
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
        "List<{0}>" -f $Method.ReturnType.Type.Type
    } elseif ($AsMediaDownloader -eq $true) {
        "void"
    } else {
        $Method.ReturnType.Type.Type
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

    if ($Method.ReturnType.Type.Type -ne "void" -and -not $AsMediaDownloader -eq $true) {
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