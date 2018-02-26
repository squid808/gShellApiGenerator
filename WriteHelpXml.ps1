#TODO - fix in to using list?
function Get-GauthIdPropertyObj {
    $P = New-Object ApiMethodProperty
    $P.Name = "GAuthId"
    $P.Description = "The GAuthId representing the gShell auth credentials this cmdlet should use to run."
    $P.Required = $false
    $P.Type = New-BasicTypeStruct string
    return $P
}

function Get-TargetUserEmailObj {
    $P = New-Object ApiMethodProperty
    $P.Name = "TargetUserEmail"
    $P.Description = "The email account to be targeted by the service account."
    $P.Required = $false
    $P.Type = New-BasicTypeStruct string
    return $P
}

function Add-GShellPropertiesToSet ($Method, [ref]$PropertiesHash, [ref]$UniqueParams) {
    $Hash = $PropertiesHash.Value
    $Unique = $UniqueParams.Value

    $AddedUniqueGauthId = $false
    $AddedUniqueTargetUserEmail = $false
    foreach ($Key in $Hash.Keys) {

        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase","AuthenticatedCmdletBase") -contains $Method.Api.CmdletBaseType) {
            $P = Get-GauthIdPropertyObj

            $Hash[$Key].Add($P) | Out-Null
            if ($AddedUniqueGauthId -eq $false) {
                $Unique.Add($P) | Out-Null
                $AddedUniqueGauthId = $true
            }
        }

        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase") -contains $Method.Api.CmdletBaseType) {
            $P = Get-TargetUserEmailObj

            $Hash[$Key].Add($P) | Out-Null
            if ($AddedUniqueTargetUserEmail -eq $False) {
                $Unique.Add($P) | Out-Null
                $AddedUniqueTargetUserEmail = $true
            }
        }
    }
}

function Get-MCHelpMediaUploadProperties ($Method) {

    $UniqueParams = New-Object System.Collections.ArrayList

    $PropertiesHash = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
        $PropertiesHash["WithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["NoBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["MediaWithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["MediaNoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $DefaultParamSet = "Default"
        $PropertiesHash["Default"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"] = (New-Object System.Collections.ArrayList)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $UploadParams = $Method.UploadMethod.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {
        
        #specify the param sets if needed, regardless still increment the PropertiesHash 
        foreach ($Key in $PropertiesHash.Keys) {
            $PropertiesHash[$Key].Add($Parameter) | Out-Null
        }

        $UniqueParams.Add($Parameter) | Out-Null
    }

    #Now add any methods from the media upload method that weren't used already
    foreach ($Parameter in $UploadParams) {

        if ($MethodParams.Name -contains $Parameter.Name `
            -and (($MethodParams | where {$_.Name -eq $Parameter.Name}).Type.Type -ne $Parameter.Type.Type)) {
            $Parameter.Name = "MediaUpload" + $Parameter.Name
        }

        if ($MethodParams.Name -notcontains $Parameter.Name) {

            foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "Media*"})) {
                $PropertiesHash[$Key].Add($Parameter) | Out-Null
            }
        }

        $UniqueParams.Add($Parameter) | Out-Null
    }

    #Handle the additional upload methods
    $PMedia = Get-MediaUploadProperty -Method $Method

    foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "Media*"})) {
        $PropertiesHash[$Key].Add($PMedia) | Out-Null
    }

    $UniqueParams.Add($PMedia) | Out-Null

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "*WithBody"})) {
            $PropertiesHash[$Key].Add($Method.BodyParameter) | Out-Null
        }

        $UniqueParams.Add($Method.BodyParameter) | Out-Null

        #Now write the non-body options
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where {$_.Name -ne "ETag"})) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "*NoBody"})) {
                $PropertiesHash[$Key].Add($BodyProperty) | Out-Null
            }

            $UniqueParams.Add($BodyProperty) | Out-Null
        }
    }

    Add-GShellPropertiesToSet -Method $Method -PropertiesHash ([ref]$PropertiesHash) -UniqueParams ([ref]$UniqueParams)

    return $UniqueParams, $PropertiesHash, $DefaultParamSet
}

function Get-MCHelpMediaDownloadProperties($Method) {
    
    $UniqueParams = New-Object System.Collections.ArrayList

    #expect that there are two methods and maybe a body
    $PropertiesHash = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
        $PropertiesHash["WithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["NoBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["MediaWithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["MediaNoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $DefaultParamSet = "Default"
        $PropertiesHash["Default"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"] = (New-Object System.Collections.ArrayList)
    }

    $MethodParams = $Method.Parameters | where `
        { $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true }

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {
        foreach ($Key in $PropertiesHash.Keys) {
            $PropertiesHash[$Key].Add($Parameter) | Out-Null
        }

        $UniqueParams.Add($Parameter) | Out-Null
    }

    #Handle the additional download methods
    $PMedia = Get-MediaDownloadProperty -Method $Method

    foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "Media*"})) {
        $PropertiesHash[$Key].Add($PMedia) | Out-Null
    }

    $UniqueParams.Add($PMedia) | Out-Null

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "*WithBody"})) {
            $PropertiesHash[$Key].Add($Method.BodyParameter) | Out-Null
        }

        $UniqueParams.Add($Method.BodyParameter) | Out-Null

        #Now write the non-body options
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where {$_.Name -ne "ETag"})) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            foreach ($Key in ($PropertiesHash.Keys | where {$_ -like "*NoBody"})) {
                $PropertiesHash[$Key].Add($BodyProperty) | Out-Null
            }

            $UniqueParams.Add($BodyProperty) | Out-Null
        }
    }

    Add-GShellPropertiesToSet -Method $Method -PropertiesHash ([ref]$PropertiesHash) -UniqueParams ([ref]$UniqueParams)

    return $UniqueParams, $PropertiesHash, $DefaultParamSet
}

#write the parameters for the cmdlet
function Get-MCHelpProperties ($Method) {
    $PropertiesHash = @{}
    $UniqueParams = New-Object System.Collections.ArrayList

    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
        $PropertiesHash["WithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["NoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $DefaultParamSet = $null
        $PropertiesHash["__AllParameterSets"] = (New-Object System.Collections.ArrayList)
    }

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Parameter in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {

        foreach ($Key in $PropertiesHash.Keys) {
            $PropertiesHash[$Key].Add($Parameter) | Out-Null
        }

        $UniqueParams.Add($Parameter) | Out-Null
    }
    
    if ($Method.HasBodyParameter -eq $true) {
        
        $PropertiesHash["WithBody"].Add($Method.BodyParameter) | Out-Null
        $UniqueParams.Add($Method.BodyParameter) | Out-Null

        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where {$_.Name -ne "ETag"})) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            $PropertiesHash["NoBody"].Add($BodyProperty) | Out-Null
            $UniqueParams.Add($BodyParameter) | Out-Null
        }
    }

    Add-GShellPropertiesToSet -Method $Method -PropertiesHash ([ref]$PropertiesHash) -UniqueParams ([ref]$UniqueParams)

    return $UniqueParams, $PropertiesHash, $DefaultParamSet
}

function Format-DescriptionSynopsis ($Description) {
    $Description = $Description -split "(?:`n|`r`n?)" | select -First 1

    $Description = ($Description -split "[.]" | select -First 1) + "."

    return $Description
}

function Write-MCHelpParams ($ParameterSet, [ref]$xmlWriter) {
    $x = $xmlWriter.Value
    
    $position = 0

    foreach ($Parameter in $ParameterSet) {
        $x.WriteComment(("Parameter: " + $Parameter.Name))
        $x.WriteStartElement("command:parameter")

        try {
        $x.WriteAttributeString("required",$null,($Parameter.Required.ToString().ToLower()))
        } catch {
            #TODO: fix this?
            write-host ""
        }

        $x.WriteAttributeString("globbing", $null, "false")
        if ($Parameter.Required -eq $true) {
            $pipelineInput = "true (ByPropertyName)"
        } else {
            $pipelineInput = "false"
        }
        $x.WriteAttributeString("pipelineInput",$null,$pipelineInput)
        $x.WriteAttributeString("position",$null,$position.ToString())
        $position++

        $x.WriteElementString("maml:name",$Parameter.Name)

        $x.WriteStartElement("maml:description")

        $DescriptionLines = $Parameter.Description -split "(?:`n|`r`n?)"
        foreach ($DLine in $DescriptionLines) {
            if (-not [string]::IsNullOrWhiteSpace($DLine)) {
                $x.WriteElementString("maml:para",$DLine)
            }
        }
        #end maml:description
        $x.WriteEndElement()

        #PARAMVALUE REQUIRED
        $x.WriteStartElement("command:parameterValue")
        $x.WriteAttributeString("required", $Parameter.Required.ToString().ToLower())
        $x.WriteString($Parameter.Type.HelpDocShortType)
        $x.WriteEndElement()

        $x.WriteStartElement("dev:type")
        $x.WriteElementString("maml:name",$Parameter.Type.HelpDocLongType)
        $x.WriteEndElement()

        if ($Parameter.Type.Type -like "*enum*") {
            if ($Parameter.ReflectedObj.GetType() -like "*RuntimePropertyInfo*") {
                $EnumValues = $Parameter.ReflectedObj.PropertyType.GenericTypeArguments[0].GetFields() `
                    | where {$_.FieldType.IsEnum -eq $true} | select -ExpandProperty Name
            } else {
                $EnumValues = $Parameter.ReflectedObj.ParameterType.GenericTypeArguments[0].GetFields() `
                    | where {$_.FieldType.IsEnum -eq $true} | select -ExpandProperty Name
            }
            $x.WriteStartElement("command:parameterValueGroup")
            foreach ($Enum in $EnumValues) {
                $x.WriteStartElement("command:parameterValue")
                $x.WriteAttributeString("required", "false")
                $x.WriteAttributeString("command:variableLength", "false")
                $x.WriteString($Enum)
                $x.WriteEndElement()
            }
            $x.WriteEndElement()
        }

        #end command:parameter
        $x.WriteEndElement()
    }
}

function Write-MCHelpInputTypes ($ParameterSet, [ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:inputTypes")

    foreach ($Parameter in $ParameterSet) {
        
        $x.WriteStartElement("command:inputType")

        $x.WriteStartElement("dev:type")
        $x.WriteElementString("maml:name",$Parameter.Type.HelpDocLongType)
        $x.WriteEndElement()

        $x.WriteStartElement("maml:description")
        $DescriptionLines = $Parameter.Description -split "(?:`n|`r`n?)"
        foreach ($DLine in $DescriptionLines) {
            if (-not [string]::IsNullOrWhiteSpace($DLine)) {
                $x.WriteElementString("maml:para",$DLine)
            }
        }
        #end maml:description
        $x.WriteEndElement()

        #end command:inputType
        $x.WriteEndElement()
    }

    #end command:inputTypes
        $x.WriteEndElement()
}

function Write-MCHelpReturnValues ($Method,[ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:returnValues")

    if ($Method.ReturnType.Type -ne $null -and $Method.ReturnType.Type.Type -ne "void") {
        $x.WriteStartElement("dev:type")
        $x.WriteElementString("maml:name",$Method.ReturnType.Type.HelpDocLongType)
        $x.WriteEndElement()
    }

    #end command:returnValues
    $x.WriteEndElement()
}

function Write-MCHelpSyntaxParams ($Verb, $Noun, $ParameterSetName, $ParameterSet, [ref]$xmlWriter) {
    $x = $xmlWriter.Value
    
    $x.WriteComment("Parameter set: $ParameterSetName")
    $x.WriteStartElement("command:syntaxItem")

    $x.WriteElementString("maml:name","$Verb-$Noun")

    Write-MCHelpParams -ParameterSet $ParameterSet -xmlWriter ([ref]$x)

    #end command:syntaxItem
    $x.WriteEndElement()
}

function Write-MCHelpAlertSet ([ref]$xmlWriter) {

    $x = $xmlWriter.Value

    #AlertSet
    $x.WriteStartElement("maml:alertSet")
    $x.WriteElementString("maml:title","About this Cmdlet")
    $x.WriteStartElement("maml:alert")
    $x.WriteElementString("maml:para","Part of the gShell Project, relating to the Google Directory API; see Related Links or use the -Online parameter.")
    $x.WriteEndElement()

    #end maml:alertSet
    $x.WriteEndElement()

}

function Write-MCHelpExample ($Method, $Verb, $Noun, $PropertiesHash, $PropertySetName, $ExampleNumber, [ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:example")

    $x.WriteElementString("maml:title","----------  EXAMPLE $ExampleNumber  ----------")
    $PropertiesList = New-Object System.Collections.ArrayList
    
    $PropertiesToUse = New-Object System.Collections.ArrayList
    $PropertiesHash[$PropertySetName] | where {$_.Required -eq $true} | % {$PropertiesToUse.Add($_) | Out-Null}

    if ($PropertySetName -eq "NoBody") {
        #Use anything but the gShell properties, and only the first 2 for the body property
        $PropertiesHash[$PropertySetName] | where {$Method.BodyParameter.SchemaObject.Properties -contains $_.name} `
            | select -First 2 | % {$PropertiesToUse.Add($_) | Out-Null}

    }
    
    foreach ($P in $PropertiesToUse) {
        if ($P.Name -eq "Body") {
            #TODO: STart here, figure out why this isn't working
            $ObjNoun = "G" + $Method.Api.Name + $Method.BodyParameter.Type.HelpDocShortType + "Obj"
            $VarName = "-" + $P.Name + ' (New-' + $ObjNoun + "...)"
            $PropertiesList.Add($VarName) | Out-Null
        } else {
            $VarName = "-" + $P.Name + ' $Some' + $P.Name + (ConvertTo-FirstUpper ($P.Type.HelpDocShortType -split "[^A-Za-z]" | select -first 1)) + "Obj"
            $PropertiesList.Add($VarName) | Out-Null
        }
    }

    $PropertiesList = $PropertiesList -join " "

    $x.WriteElementString("dev:code","PS C:\> $Verb-$Noun $PropertiesList")

    $x.WriteStartElement("dev:remarks")
    $x.WriteElementString("maml:para","This automatically generated example shows a minimal way to call this cmdlet.")

    #end dev:remarks
    $x.WriteEndElement()

    #end command:example
    $x.WriteEndElement()
}

function Write-MCHelpExamples ($Method, $Verb, $Noun, $PropertiesHash, [ref]$xmlWriter) {
    #STARTHERE - need to expand on the example and make sure that it covers multiple param sets and params
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:examples")

    $Counter = 1
    
    foreach ($Key in $PropertiesHash.Keys) {
        #TODO: Start here, figure out how to include properties that aren't required when using a NoBody option
        Write-MCHelpExample $Method $Verb $Noun $PropertiesHash $Key $Counter ([ref]$x)
        $Counter++
    }

    #end command:examples
    $x.WriteEndElement()
}

function Write-MCHelpRelatedLink ($LinkText, $Link, [ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("maml:navigationLink")

    $x.WriteElementString("maml:linkText",$LinkText)
    $x.WriteElementString("maml:uri",$Link)

    #end maml:navigationLink
    $x.WriteEndElement()
}

function Write-MCHelpRelatedLinks ([ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("maml:relatedLinks")

    Write-MCHelpRelatedLink -LinkText "[Getting started with gShell]" `
        -Link "https://github.com/squid808/gShell/wiki/Getting-Started" `
        -xmlWriter ([ref]$x)

    #end maml:relatedLinks
    $x.WriteEndElement()
}

function Write-MCHelpMethod ($Method, [ref]$xmlWriter, $Level=0) {

    $x = $xmlWriter.Value

    $Verb = Get-McVerb $Method.Name

    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
    
    $x.WriteComment("Cmdlet: $Verb-$Noun")
    $x.WriteStartElement("command:command")
    $x.WriteAttributeString("xmlns:maml",$null,"http://schemas.microsoft.com/maml/2004/10")
    $x.WriteAttributeString("xmlns:command",$null,"http://schemas.microsoft.com/maml/dev/command/2004/10")
    $x.WriteAttributeString("xmlns:dev",$null,"http://schemas.microsoft.com/maml/dev/2004/10")

    $x.WriteStartElement("command:details")

    $x.WriteElementString("command:name","$Verb-$Noun")
    $x.WriteElementString("command:verb","$Verb")
    $x.WriteElementString("command:noun","$Noun")

    #start maml:description (synopsis)
    $x.WriteStartElement("maml:description")
    $x.WriteElementString("maml:para",(Format-DescriptionSynopsis $Method.Description))
    $x.WriteEndElement()

    #end command:details
    $x.WriteEndElement()

    $DescriptionLines = $Method.Description -split "(?:`n|`r`n?)"
    
    $x.WriteStartElement("maml:description")
    foreach ($DLine in $DescriptionLines) {
        if (-not [string]::IsNullOrWhiteSpace($DLine)) {
            $x.WriteElementString("maml:para",$DLine)
        }
    }
    $x.WriteEndElement()

    $x.WriteStartElement("command:syntax")

    #Get the parameter sets and default parameter set
    if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {
        $UniqueParams, $PropertiesHash, $DefaultParamSet = Get-MCHelpMediaUploadProperties -Method $Method
    } else {
        if ($Method.SupportsMediaDownload -eq $true) {
            $UniqueParams, $PropertiesHash, $DefaultParamSet = Get-MCHelpMediaDownloadProperties -Method $Method
        } else {
            $UniqueParams, $PropertiesHash, $DefaultParamSet = Get-MCHelpProperties -Method $Method
        }
    }

    if  ($DefaultParamSet -ne $null) {
        Write-MCHelpSyntaxParams $Verb $Noun $DefaultParamSet $PropertiesHash[$DefaultParamSet] ([ref]$x)
    }
    
    foreach ($ParamSetName in ($PropertiesHash.Keys | where {$_ -ne $DefaultParamSet})) {
        Write-MCHelpSyntaxParams $Verb $Noun $ParamSetName $PropertiesHash[$ParamSetName] ([ref]$x)
    }

    #end command:syntax
    $x.WriteEndElement()

    $x.WriteStartElement("command:parameters")
    Write-MCHelpParams -ParameterSet ($UniqueParams | sort Name) -xmlWriter ([ref]$x)
    #end <command:parameters>
    $x.WriteEndElement()

    Write-MCHelpInputTypes -ParameterSet ($UniqueParams | sort Name) -xmlWriter ([ref]$x)

    Write-MCHelpReturnValues -Method $Method -xmlWriter ([ref]$x)

    Write-MCHelpAlertSet -xmlWriter ([ref]$x)

    Write-MCHelpExamples -Method $Method -Verb $Verb -Noun $Noun -xmlWriter ([ref]$x) -PropertiesHash $PropertiesHash

    Write-MCHelpRelatedLinks -xmlWriter ([ref]$x)

    #end command:command
    $x.WriteEndElement()
}

function Write-MCHelpResource ($Resource, [ref]$xmlWriter) {

    foreach ($Method in $Resource.Methods) {
        Write-MCHelpMethod $Method ([ref]$xmlWriter.Value)
    }
}

function Write-MCHelpResources ($Resources, [ref]$xmlWriter) {
#should return with each resource in its own namespace at the same level?

    foreach ($Resource in $Resources) {
        Write-MCHelpResource $Resource ([ref]$xmlWriter.Value)

        if ($Resource.ChildResources.Count -gt 0) {
            Write-MCHelpResources $Resource.ChildResources ([ref]$xmlWriter.Value)
        }
    }
}

function Write-MCHelp ($Api, $OutPath) {

    $HelpFileName = "gShell." + $Api.NameAndVersion + ".dll-Help.xml"
    $Path = ([System.IO.Path]::Combine($OutPath, "bin\Debug", $HelpFileName))
    
    $xmlWriter = New-Object System.XML.XmlTextWriter($Path,$Null)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $xmlWriter.IndentChar = "`t"
    $xmlWriter.WriteStartDocument()

    $xmlWriter.WriteStartElement("helpItems")
    $xmlWriter.WriteAttributeString("schema","maml")
    $xmlWriter.WriteAttributeString("xmlns","http://msh")

    $Resources = Write-MCHelpResources $Api.Resources ([ref]$xmlWriter)

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

    #return $text

    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()
}

#TODO: write help for upload / downloads