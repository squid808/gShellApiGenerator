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
    $MethodReturnTypeFullName = $Method.ReturnType.Type.Type

    $resultsType = $Method.ReturnType.Type.Type

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
            Add-String $Params ("{0} {1}" -f $P.Type.Type, $P.Name)
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
                -f $P.Type.Type, $P.Name, $InitValue, (Format-CommentString $P.Description)) $Level))
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
    $MethodReturnType = $Method.ReturnType.Type.Type
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
        "List<{0}>" -f $Method.ReturnType.Type.Type
    } else {
        $Method.ReturnType.Type.Type
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
        if ($Method.ReturnType.Type.Type -ne "void") {
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