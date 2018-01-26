#TODO - fix in to using list?
function Get-MCHelpMediaUploadPropertySets ($Method) {

    $PropertiesHash = @{}
    $PropertiesHash["Media"] = @{}
    $PropertiesHash["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $PropertiesHash["NoMedia"]["WithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["NoMedia"]["NoBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["MediaWithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["MediaNoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $PropertiesHash["NoMedia"]["Default"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["Media"] = (New-Object System.Collections.ArrayList)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $UploadParams = $Method.UploadMethod.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {

        #if ($UploadParams.Name -contains $Parameter.Name) {
        #    #contained in both methods
        #    $KeysToProcess = @("NoMedia","Media")
        #} else {
        #    $KeysToProcess = @("NoMedia")
        #}
        
        #specify the param sets if needed, regardless still increment the PropertiesHash 
        foreach ($Key in $PropertiesHash.Keys) {
            foreach ($SubKey in $PropertiesHash[$Key].Keys) {
                $PropertiesHash[$Key][$SubKey].Add($Parameter) | Out-Null
            }
        }
    }

    #Now add any methods from the media upload method that weren't used already
    foreach ($Parameter in $UploadParams) {

        if ($MethodParams.Name -contains $Parameter.Name `
            -and (($MethodParams | where Name -eq $Parameter.Name).Type.Type -ne $Parameter.Type.Type)) {
            $Parameter.Name = "MediaUpload" + $Parameter.Name
        }

        if ($MethodParams.Name -notcontains $Parameter.Name) {

            foreach ($SubKey in $PropertiesHash["Media"].Keys) {
                $PropertiesHash["Media"][$SubKey].Add($Parameter) | Out-Null
            }
        }
    }

    #Handle the additional upload methods
    $PMedia = Get-MediaUploadProperty -Method $Method

    foreach ($SubKey in $PropertiesHash["Media"].Keys) {
        $PropertiesHash["Media"][$SubKey].Add($PMedia) | Out-Null
    }

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        foreach ($Key in $PropertiesHash.Keys) {
            foreach ($SubKey in ($PropertiesHash[$Key].Keys | where {$_ -like "*WithBody"})) {
                $PropertiesHash[$Key][$SubKey].Add($Method.BodyParameter) | Out-Null
            }
        }

        #Now write the non-body options
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            foreach ($Key in $PropertiesHash.Keys) {
                foreach ($SubKey in ($PropertiesHash[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $PropertiesHash[$Key][$SubKey].Add($BodyProperty) | Out-Null
                }
            }
        }
    }

    return $PropertiesHash
}

function Get-MCHelpMediaDownloadProperties($Method) {
    
    #expect that there are two methods and maybe a body
    $PropertiesHash = @{}
    $PropertiesHash["Media"] = @{}
    $PropertiesHash["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $PropertiesHash["NoMedia"]["WithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["NoMedia"]["NoBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["MediaWithBody"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["MediaNoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $PropertiesHash["NoMedia"]["Default"] = (New-Object System.Collections.ArrayList)
        $PropertiesHash["Media"]["Media"] = (New-Object System.Collections.ArrayList)
    }

    $MethodParams = $Method.Parameters | where `
        { $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true }

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {
        foreach ($Key in $PropertiesHash) {
            foreach ($SubKey in $PropertiesHash[$Key].Keys) {
                $PropertiesHash[$Key][$SubKey].Add($Parameter) | Out-Null
            }
        }
    }

    #Handle the additional download methods
    $PMedia = Get-MediaDownloadProperty -Method $Method

    foreach ($SubKey in $PropertiesHash["Media"].Keys) {
        $PropertiesHash["Media"][$SubKey].Add($PMedia) | Out-Null
    }

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        foreach ($Key in $PropertiesHash.Keys) {
            foreach ($SubKey in ($PropertiesHash[$Key].Keys | where {$_ -like "*WithBody"})) {
                $PropertiesHash[$Key][$SubKey].Add($Method.BodyParameter) | Out-Null
            }
        }

        #Now write the non-body options
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            foreach ($Key in $PropertiesHash.Keys) {
                foreach ($SubKey in ($PropertiesHash[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $PropertiesHash[$Key][$SubKey].Add($BodyProperty) | Out-Null
                }
            }
        }
    }

    return $PropertiesHash
}

#write the parameters for the cmdlet
function Get-MCHelpProperties ($Method) {
    $PropertiesHash = @{}

    $PropertiesHash["NoBody"] = (New-Object System.Collections.ArrayList)

    if ($Method.HasBodyParameter -eq $true) {
        $PropertiesHash["WithBody"] = (New-Object System.Collections.ArrayList)
    }

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Parameter in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {

        foreach ($Key in $PropertiesHash.Keys) {
            $PropertiesHash[$Key].Add($Parameter) | Out-Null
        }
    }
    
    if ($Method.HasBodyParameter -eq $true) {
        
        $PropertiesHash["WithBody"].Add($Method.BodyParameter) | Out-Null

        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $BodyProperty.Name = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            $PropertiesHash["NoBody"].Add($BodyProperty) | Out-Null
        }
    }

    return $PropertiesHash
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
                $x.WriteAttributeString("variableLength", "false")
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

function Write-MCHelpExample ($Verb, $Noun, $PropertySet, $ExampleNumber, [ref]$xmlWriter) {
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:example")

    $x.WriteElementString("maml:title","----------  EXAMPLE $ExampleNumber  ----------")
    $PropertiesList = New-Object System.Collections.ArrayList
    
    foreach ($P in $PropertySet) {
        
        $VarName = "-" + $P.Name + ' $Some' + $P.Name + (ConvertTo-FirstUpper ($P.Type.HelpDocShortType -split "[^A-Za-z]" | select -first 1)) + "Obj"
        $PropertiesList.Add($VarName) | Out-Null
    }

    $PropertiesList = $PropertiesList -join " "

    $x.WriteElementString("dev:code","PS C:\> $Verb-$Noun $PropertiesList")

    $x.WriteStartElement("dev:remarks")
    $x.WriteElementString("maml:para","This automatically generated example serves to show the bare minimum required to call this Cmdlet.")

    #end dev:remarks
    $x.WriteEndElement()

    #end command:example
    $x.WriteEndElement()
}

function Write-MCHelpUploadExamples ($Verb, $Noun, $PropertySet, $ExampleNumber, [ref]$XmlWriter) {
    
}

function Write-MCHelpExamples ($Method, $Verb, $Noun, [ref]$xmlWriter) {
    #STARTHERE - need to expand on the example and make sure that it covers multiple param sets and params
    $x = $xmlWriter.Value

    $x.WriteStartElement("command:examples")

    $Properties = Get-MCHelpProperties $Method

    $Counter = 1

    foreach ($Key in $Properties.Keys) {
        #TODO: Start here, figure out how to include properties that aren't required when using a NoBody option
        Write-MCHelpExample $Verb $Noun  ($Properties[$Key] | where Required -eq $true) $Counter ([ref]$x)
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

#write the parameters for the cmdlet
#function Write-MCHelpProperties ($Method, $Verb, $Noun, [ref]$xmlWriter) {
#
#    $x = $xmlWriter.Value
#    
#    $StandardPositionInt = 0
#    $BodyPositionInt = 0
#
#    $UniqueParams = New-Object System.Collections.ArrayList
#    $ParameterSets = @{}
#
#    if ($Method.HasBodyParameter -eq $true) {
#        $ParameterSets["WithBody"] = (New-Object System.Collections.ArrayList)
#        $ParameterSets["NoBody"] = (New-Object System.Collections.ArrayList)
#    } else {
#        $ParameterSets["__AllParameterSets"] = (New-Object System.Collections.ArrayList)
#    }
#
#    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
#    foreach ($Property in ($Method.Parameters | where { `
#            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {
#
#        foreach ($Key in $ParameterSets.Keys) {
#            $ParameterSets[$Key].Add($Property) | Out-Null
#        }
#
#        $UniqueParams.Add($Property) | Out-Null
#    }
#    
#    if ($Method.HasBodyParameter -eq $true) {
#
#        $ParameterSets["WithBody"].Add($Method.BodyParameter) | Out-Null
#        $UniqueParams.Add($Method.BodyParameter) | Out-Null
#
#        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
#            
#            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
#                $P = New-Object ApiMethodProperty
#                $P.Name = $Method.BodyParameter.SchemaObject.Type.Type + $BodyProperty.Name
#                $P.Description = $BodyProperty.Description
#                $P.Required = $BodyProperty.Required
#                $P.Type = $BodyProperty.Type
#                $ParameterSets["NoBody"].Add($P) | Out-Null
#                $UniqueParams.Add($P) | Out-Null
#            } else {
#                $ParameterSets["NoBody"].Add($BodyProperty) | Out-Null
#                $UniqueParams.Add($BodyProperty) | Out-Null
#            }            
#        }
#    }
#
#    $AddedUniqueGauthId = $false
#    $AddedUniqueTargetUserEmail = $false
#    foreach ($Key in $ParameterSets.Keys) {
#
#        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase","AuthenticatedCmdletBase") -contains $Method.Api.CmdletBaseType) {
#            $P = New-Object ApiMethodProperty
#            $P.Name = "GAuthId"
#            $P.Description = "The GAuthId representing the gShell auth credentials this cmdlet should use to run."
#            $P.Required = $false
#            $P.Type = New-BasicTypeStruct string
#
#            $ParameterSets[$Key].Add($P) | Out-Null
#            if ($AddedUniqueGauthId -eq $false) {
#                $UniqueParams.Add($P) | Out-Null
#                $AddedUniqueGauthId = $true
#            }
#        }
#
#        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase") -contains $Method.Api.CmdletBaseType) {
#            $P = New-Object ApiMethodProperty
#            $P.Name = "TargetUserEmail"
#            $P.Description = "The email account to be targeted by the service account."
#            $P.Required = $false
#            $P.Type = New-BasicTypeStruct string
#
#            $ParameterSets[$Key].Add($P) | Out-Null
#            if ($AddedUniqueTargetUserEmail -eq $False) {
#                $UniqueParams.Add($P) | Out-Null
#                $AddedUniqueTargetUserEmail = $true
#            }
#        }
#    }
#
#    if ($Method.HasBodyParameter -eq $true) {
#        $DefaultParamSet = "WithBody"
#    } elseif ($Method.SupportsMediaDownload -eq $true) {
#        $DefaultParamSet = "Default"
#    } else {
#        $DefaultParamSet = "__AllParameterSets"
#    }
#
#    Write-MCHelpSyntaxParams $Verb $Noun $DefaultParamSet $ParameterSets[$DefaultParamSet] ([ref]$x)
#    
#    foreach ($ParamSetName in ($ParameterSets.Keys | where {$_ -ne $DefaultParamSet})) {
#        Write-MCHelpSyntaxParams $Verb $Noun $ParamSetName $ParameterSets[$ParamSetName] ([ref]$x)
#    }
#
#    return $UniqueParams
#}

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

    if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {

    } else {
        $UniqueParams = Write-MCHelpProperties $Method $Verb $Noun -xmlWriter ([ref]$x)
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

    Write-MCHelpExamples -Method $Method -Verb $Verb -Noun $Noun -xmlWriter ([ref]$x)

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

function Write-MCHelp ($Api, $ApiName, $OutPath) {

    $HelpFileName = $ApiName + ".dll-Help.xml"
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