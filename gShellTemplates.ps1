﻿function Write-GShellDotNetWrapper_ResourceInstantiations ($Resources, $Level=0) {

    $list = New-Object System.Collections.ArrayList

    foreach ($R in $Resources)  {

        $text = "public {0} {1} = new {0}();" -f $R.Name, $R.NameLower

        $list.Add($text) | Out-Null
    }

    $string = "{%T}" + ($list -join "`r`n`r`n")

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

function Write-GShellMethodProperties_MethodParams ($Method, [bool]$RequiredOnly) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($RequiredOnly -eq $False -or ($RequiredOnly -eq $true -and $P.Required -eq $true)){
            $Params.Add(("{0} {1}" -f $P.Type, $P.Name)) | Out-Null
        }
    }

    $result = $Params -join ", "

    return $result
}

function Write-GShellDotNetWrapper_ResourceWrappedMethod ($Method) {
    $MethodName = $Method.Name
    $MethodReturnType = $Method.ReturnType.FullName

    #TODO - figure out a way to determine which parameters are optional *as far as the API is concerned*
    #LOOK IN TO THE INIT PARAMETERS METHOD OF THE REQUEST METHOD!
    $PropertiesObj = if ($Method.Parameters.Count -ne 0) {
        "A"
    }
    
    $text = @"
public $MethodReturnType $MethodName ({0}StandardQueryParameters StandardQueryParams = null) {{
    
    if (StandardQueryParams != null) {{
        request.Fields = StandardQueryParams.fields;
        request.QuotaUser = StandardQueryParams.quotaUser;
        request.UserIp = StandardQueryParams.userIp;
    }}
}}
"@ -f $PropertiesObj

    return $text

}

#TODO
function Write-GShellDotNetWrapper_ResourceWrappedMethods ($Resource, $Level=0) {
    $list = New-Object System.Collections.ArrayList

    $ResourceName = $Resource.Name
    

    foreach ($M in $Resource.Methods) {
        $M = Write-GShellDotNetWrapper_ResourceWrappedMethod $M

        $list.Add($text) | Out-Null
    }


    $string = "{%T}" + ($list -join "`r`n`r`n")

    $string = Set-Indent -String $string -TabCount $Level
    
    return $string
}

function Write-GShellDotNetWrapper ($Api) {

    $ApiRootNamespace = $Api.RootNamespace
    $ApiClassName = $Api.Name
    $ApiClassNameBase = $ApiClassName + "Base"
    $ApiVersionNoDots = $Api.NameAndVersion -replace "[.]","_"
    $ApiModuleName = $Api.RootNamespace + "." + $ApiVersionNoDots
    $ApiNameAndVersion = $ApiClassName + ":" + $ApiVersionNoDots

    $Resources = "//TODO: MAKE WRITE-GShellDotNetRESOURCES"
    $ResourceInstantiatons = Write-GShellDotNetWrapper_ResourceInstantiations $Api.Resources
    $ResourceWrappedMethods = "//TODO: ResourceWrappedMethods here"
    
    $WorksWithGmail = "//TODO: WORKS WITH GMAIL?"

    $text = @"
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

using gShell.Cmdlets.Utilities.OAuth2;
using gShell.dotNet;

namespace gShell.Cmdlets.$ApiClassName {

    using System;
    using System.Collections.Generic;
    using System.Management.Automation;
    
    using Google.Apis.Auth.OAuth2;
    using Google.Apis.Services;
    using $ApiVersionNoDots = $ApiModuleName;
    using Data = $ApiModuleName.Data;
    
    using gShell.dotNet.Utilities;
    using gShell.dotNet.Utilities.OAuth2;
    using g$ApiClassName = gShell.dotNet.$ApiClassName;

    /// <summary>
    /// A PowerShell-ready wrapper for the $ApiClassName api, as well as the resources and methods therein.
    /// </summary>
    public abstract class $ApiClassNameBase : OAuth2CmdletBase
    {

        #region Properties

        /// <summary>The gShell dotNet class wrapper base.</summary>
        protected static g$ApiClassName mainBase { get; set; }

        /// <summary>
        /// Required to be able to store and retrieve the mainBase from the ServiceWrapperDictionary
        /// </summary>
        protected override Type mainBaseType { get { return typeof($ApiClassName); } }

        $Resources

        #endregion

        #region Constructors
        protected $ApiClassNameBase()
        {
            mainBase = new g$ApiClassName();

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

$Test = @"
namespace gShell.dotNet
{
    using System;
    using System.Collections.Generic;

    using gShell.dotNet;
    using gShell.dotNet.Utilities.OAuth2;

    using $ApiVersionNoDots = $ApiModuleName;
    using Data = $ApiModuleName.Data;

    /// <summary>The dotNet gShell version of the $ApiClassName api.</summary>
    public class $ApiClassName : ServiceWrapper<$ApiVersionNoDots.$ApiClassNameService>
    {
        protected override bool worksWithGmail { get { return $WorksWithGmail; } }

        /// <summary>Creates a new $ApiVersionNoDots.$ApiClassName service.</summary>
        /// <param name="domain">The domain to which this service will be authenticated.</param>
        /// <param name="authInfo">The authenticated AuthInfo for this user and domain.</param>
        /// <param name="gShellServiceAccount">The optional email address the service account should impersonate.</param>
        protected override $ApiVersionNoDots.$ApiClassNameService CreateNewService(string domain, AuthenticatedUserInfo authInfo, string gShellServiceAccount = null)
        {
            return new $ApiVersionNoDots.$ApiClassNameService(OAuth2Base.GetInitializer(domain, authInfo, gShellServiceAccount));
        }

        /// <summary>Returns the api name and version in {name}:{version} format.</summary>
        public override string apiNameAndVersion { get { return "$ApiNameAndVersion"; } }

        {% for resource in api.resources %}
        /// <summary>Gets or sets the {{ resource.codeName }} resource class.</summary>
        public {{ resource.className }} {{ resource.codeName }}{ get; set; }{% endfor %}
        {% endnoblank %}

        public $ApiClassName()
        {{% indent %}
        {% for resource in api.resources %}{{ resource.codeName }} = new {{ resource.className }}();{% endfor %}
        {% endindent %}}

        {# RECURSE THROUGH RESOURCES HERE #}
        {% for resource in api.resources %}{% call_template _gshell_dotnet_resource resource=resource %}{% endfor %}
    }
}
"@

$RestJson = Load-RestJsonFile admin reports_v1
#$RestJson = Load-RestJsonFile discovery v1
$LibraryIndex = Get-JsonIndex $LibraryIndexRoot
$Api = Invoke-GShellReflection $RestJson $LibraryIndex

$Resources = $Api.Resources
$Resource = $Resources[0]
$Methods = $Resource.Methods
$Method = $Methods[1]
$M = $Method
$Init = $M.ReflectedObj.ReturnType.DeclaredMethods | where name -eq "InitParameters"

#Write-GShellDotNetWrapper_ResourceWrappedMethods $resource

Write-GShellDotNetWrapper_ResourceWrappedMethod $M

#Write-GShellMethodProperties_MethodParams -Method $M