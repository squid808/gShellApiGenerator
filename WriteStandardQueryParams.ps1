function Write-SQP ($Api) {
    $ApiName = $Api.Name
    $ApiNameAndVersion = $Api.NameAndVersion
    $ApiRootNamespace = $Api.RootNamespace
    $StdQParamsName = $Api.Name + "StandardQueryParameters"
    $Params = New-Object System.Collections.ArrayList

    foreach ($Param in $Api.StandardQueryParams) {
        if ($Param.type -ne $null) {
            $Summary = Wrap-Text (("        /// <summary> {0} </summary>" -f (Format-CommentString $Param.description)))
            $Property = "        public {0} {1} {{ get; set; }}" -f $Param.type.type, $Param.NameLower

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
            $Signature = "        public {0} {1} {{ get; set; }}" -f $Param.type.type, $Param.NameLower

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