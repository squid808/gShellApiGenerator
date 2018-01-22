function Write-OCMethodProperties ($SchemaObj, $Level=0) {
    
    $PositionInt = 0

    $PropertiesTexts = New-Object System.Collections.ArrayList
    
    foreach ($Property in ($SchemaObj.Properties | where {$_.Name -ne "ETag" -and $_.ShouldIncludeInTemplates -eq $true})) {
        $CommentDescription = Format-CommentString $Property.Description
        $HelpDescription = Format-HelpMessage $Property.Description
        $Type = $Property.Type.Type
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
    $Noun = "G" + $SchemaObj.Api.Name + $SchemaObj.Type.HelpDocShortType + "Obj"
    $TypeData = $SchemaObj.Type.Type
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