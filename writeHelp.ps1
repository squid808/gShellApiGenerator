#TODO - fix in to using list?
function Format-DescriptionSynopsis ($Description) {
    $Description = $Description -split "(?:`n|`r`n?)" | select -First 1

    $Description = ($Description -split "[.]" | select -First 1) + "."

    return $Description
}

function Write-MCHelpAttribute ($Method, [ref]$xmlWriter, $Noun, $DefaultParameterSet=$Null) {
    $Verb = Get-MCAttributeVerb $Method.Name
    $DocLink = $Method.Resource.Api.DiscoveryObj.documentationLink
    
    if (-not [string]::IsNullOrWhiteSpace($DefaultParameterSet)){
        $DefaultParameterSet = " DefaultParameterSetName = `"$DefaultParameterSet`","
    }

    #$DefaultParameterSetName = if ($Method.HasBodyParameter -eq $true) {
    #    " DefaultParameterSetName = `"WithBody`","
    #}

    $text = @"
[Cmdlet($Verb, "$Noun",$DefaultParameterSet SupportsShouldProcess = true, HelpUri = @"$DocLink")]
"@

    return $text
}

function Write-MCHelpPropertyAttribute ($Mandatory, [ref]$xmlWriter, $HelpMessage, $Position, $ParameterSetName, $Level = 0) {
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

function Write-MCHelpMediaUploadProperties($Method, [ref]$xmlWriter, $Level=0) {
    
    #expect that there are two methods and maybe a body
    $Counts = @{}
    $Counts["Media"] = @{}
    $Counts["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $Counts["NoMedia"]["WithBody"] = @(0)
        $Counts["NoMedia"]["NoBody"] = @(0)
        $Counts["Media"]["MediaWithBody"] = @(0)
        $Counts["Media"]["MediaNoBody"] = @(0)
    } else {
        $Counts["NoMedia"]["Default"] = @(0)
        $Counts["Media"]["Media"] = @(0)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $UploadParams = $Method.UploadMethod.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $ParameterTexts = New-Object System.Collections.ArrayList

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {

        $required = $Parameter.Required.ToString().ToLower()

        if ($UploadParams.Name -contains $Parameter.Name) {
            #contained in both methods
            $KeysToProcess = @("NoMedia","Media")
        } else {
            $KeysToProcess = @("NoMedia")
        }

        $Attributes = New-Object System.Collections.ArrayList
        
        #if the param exists for all param sets, don't declare any
        if ($KeysToProcess.Count -gt 1) {
            $SubKey = $Counts["NoMedia"].Keys | select -First 1
            $attribute = Write-MCHelpPropertyAttribute -Mandatory $required -HelpMessage `
                $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level

            Add-String $Attributes $Attribute
        }
        
        #specify the param sets if needed, regardless still increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                if ($KeysToProcess.Count -eq 1) {
                    $attribute = Write-MCHelpPropertyAttribute -Mandatory $required -HelpMessage `
                        $Parameter.Description -Position $Counts[$Key][$SubKey][0] -Level $Level `
                        -ParameterSetName $SubKey

                    Add-String $Attributes $Attribute
                }
                $Counts[$Key][$SubKey][0]++
            }
        }

        $Attributes = $Attributes -join "`r`n"

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attributes,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Now add any methods from the media upload method that weren't used already
    foreach ($Parameter in $UploadParams) {

        if ($MethodParams.Name -contains $Parameter.Name `
            -and (($MethodParams | where Name -eq $Parameter.Name).Type -ne $Parameter.Type)) {
            $Parameter.Name = "MediaUpload" + $Parameter.Name
        }

        if ($MethodParams.Name -notcontains $Parameter.Name) {

            $required = $Parameter.Required.ToString().ToLower()
            
            $Attributes = New-Object System.Collections.ArrayList

            foreach ($SubKey in $Counts["Media"].Keys) {
                $attribute = Write-MCHelpPropertyAttribute -Mandatory $required -HelpMessage `
                    $Parameter.Description -Position $Counts["Media"][$SubKey][0] -Level $Level `
                    -ParameterSetName $SubKey

                Add-String $Attributes $Attribute
                $Counts["Media"][$SubKey][0]++
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
            $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

            $ParameterText = $summary,$attributes,$declaration -join "`r`n"

            Add-String $ParameterTexts $ParameterText
        }
    }

    #Handle the additional upload methods
    $PMedia = Get-MediaUploadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Get the content type property
    $Attributes = New-Object System.Collections.ArrayList
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f 'The content type for this file') $Level)
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage 'The content type for this file' `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $declaration  = wrap-text (set-indent ("{%T}public string ContentType { get; set; }") $Level)
    $ParameterText = $summary,$attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        $Attributes = New-Object System.Collections.ArrayList
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*WithBody"})) {
                $attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
            ($Method.BodyParameter.Type + " Body")) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCHelpPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

function Write-MCHelpMediaDownloadProperties($Method, [ref]$xmlWriter, $Level=0) {
    
    #expect that there are two methods and maybe a body
    $Counts = @{}
    $Counts["Media"] = @{}
    $Counts["NoMedia"] = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $Counts["NoMedia"]["WithBody"] = @(0)
        $Counts["NoMedia"]["NoBody"] = @(0)
        $Counts["Media"]["MediaWithBody"] = @(0)
        $Counts["Media"]["MediaNoBody"] = @(0)
    } else {
        $Counts["NoMedia"]["Default"] = @(0)
        $Counts["Media"]["Media"] = @(0)
    }

    $MethodParams = $Method.Parameters | where { `
        $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true}

    $ParameterTexts = New-Object System.Collections.ArrayList

    #First iterate all methods in the main method
    foreach ($Parameter in $MethodParams) {

        $required = $Parameter.Required.ToString().ToLower()

        $KeysToProcess = @("NoMedia","Media")
        
        #the params exist for all param sets, don't declare any
        $SubKey = $Counts["NoMedia"].Keys | select -First 1
        $attribute = Write-MCHelpPropertyAttribute -Mandatory $required -HelpMessage `
            $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level
        
        #increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                $Counts[$Key][$SubKey][0]++
            }
        }

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attribute,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Handle the additional download methods
    $PMedia = Get-MediaDownloadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        $Attributes = New-Object System.Collections.ArrayList
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*WithBody"})) {
                $attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
            ($Method.BodyParameter.Type + " Body")) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCHelpPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

function Write-MCHelpSyntaxParams ($Verb, $Noun, $ParameterSetName, $ParameterSet, [ref]$xmlWriter) {
    $x = $xmlWriter.Value
    
    $x.WriteComment("Parameter set: $ParameterSetName")
    $x.WriteStartElement("command:syntaxItem")

    $x.WriteElementString("maml:name","$Verb-$Noun")

    $position = 0

    foreach ($Parameter in $ParameterSet){
        $x.WriteComment(("Parameter: " + $Parameter.Name))
        $x.WriteStartElement("command:parameter")

        $x.WriteAttributeString("required",$null,($Parameter.Required.ToString().ToLower()))

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
        if ($Parameter.Type.ToString() -like "*enum*") {
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
        } else {

            $x.WriteStartElement("command:parameterValue")
            $x.WriteAttributeString("required", $Parameter.Required.ToString().ToLower())
            
            #TODO: yeah, make this better right
            $ParameterType = $Parameter.Type -replace "Data.","" -replace "[?]","" `
                -replace "System.Int64","long" -replace "IList<string>","string[]" `
                -replace "System.UInt64","ulong" -replace "Google.Apis.Util.Repeatable<string>","string[]"

            $x.WriteString($ParameterType)
            #if ($Parameter.ReflectedObj -eq $null) {
            #    write-host $Parameter.Type
            #    $x.WriteString($Parameter.Type)
            #} elseif ($Parameter.ReflectedObj.GetType() -like "*RuntimePropertyInfo*") {
            #    write-host $Parameter.ReflectedObj.PropertyType.Name
            #    $x.WriteString($Parameter.ReflectedObj.PropertyType.Name)
            #} else {
            #    write-host $Parameter.ReflectedObj.ParameterType.Name
            #    $x.WriteString($Parameter.ReflectedObj.ParameterType.Name)
            #}
            
            $x.WriteEndElement()
        }

        $x.WriteStartElement("dev:type")

        if (-not [string]::IsNullOrWhiteSpace($Parameter.ReflectedObj.ParameterType.FullName)) {
            $ParamType = $Parameter.ReflectedObj.ParameterType.FullName
        } elseif (-not [string]::IsNullOrWhiteSpace($Parameter.ReflectedObj.PropertyType.FullName)){
            $ParamType = $Parameter.ReflectedObj.PropertyType.FullName
        } else {
            switch ($Parameter.Type) {
                "string" {$ParamType = "System.String"}
                "default" {$ParamType = $null}
            }
            
        }
        write-host $ParamType -ForegroundColor green
        $x.WriteElementString("maml:name",$ParamType)
        $x.WriteEndElement()


        #end command:parameter
        $x.WriteEndElement()
    }

    #end command:syntaxItem
    $x.WriteEndElement()
}

#write the parameters for the cmdlet
function Write-MCHelpProperties ($Method, $Verb, $Noun, [ref]$xmlWriter) {

    $x = $xmlWriter.Value
    
    $StandardPositionInt = 0
    $BodyPositionInt = 0

    $ParameterSets = @{}

    if ($Method.HasBodyParameter -eq $true) {
        $ParameterSets["WithBody"] = (New-Object System.Collections.ArrayList)
        $ParameterSets["NoBody"] = (New-Object System.Collections.ArrayList)
    } else {
        $ParameterSets["__AllParameterSets"] = (New-Object System.Collections.ArrayList)
    }

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Property in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {

        #$summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)
        #
        #$required = $Property.Required.ToString().ToLower()
        #
        #$attributes = Write-MCHelpPropertyAttribute -Mandatory $required -HelpMessage $Property.Description `
        #    -Position $StandardPositionInt -Level $Level
        #$signature  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Property.Type, $Property.Name) $Level)
        #
        #$PropertyText = $summary,$attributes,$signature -join "`r`n"
        #
        #$PropertyTexts.Add($PropertyText) | Out-Null
        #$StandardPositionInt++

        foreach ($Key in $ParameterSets.Keys) {
            $ParameterSets[$Key].Add($Property) | Out-Null
        }
    }
    
    if ($Method.HasBodyParameter -eq $true) {
        
        #$summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)
        #$signature  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Method.BodyParameter.TypeData, `
        #    ($Method.BodyParameter.Type + " Body")) $Level)
        #$attribute = Write-MCHelpPropertyAttribute -Mandatory "true" -HelpMessage $Property.Description `
        #    -Position $StandardPositionInt -ParameterSetName "WithBody" -Level $Level
        #    
        #$BodyText = $summary,$attribute,$signature -join "`r`n"
        #$PropertyTexts.Add($BodyText) | Out-Null
        #
        #$BodyPositionInt = $StandardPositionInt
        #$StandardPositionInt++
        #
        #$BodyAttributes = New-Object System.Collections.ArrayList

        $ParameterSets["WithBody"].Add($Method.BodyParameter)

        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            #$BPName = $BodyProperty.Name
            #
            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $P = New-Object ApiMethodProperty
                $P.Name = $Method.BodyParameter.SchemaObject.Type + $BodyProperty.Name
                $P.Description = $BodyProperty.Description
                $P.Required = $BodyProperty.Required
                $P.Type = $BodyProperty.Type
                $ParameterSets["NoBody"].Add($P) | Out-Null
            } else {
                $ParameterSets["NoBody"].Add($BodyProperty) | Out-Null
            }
            #
            #$BPsummary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            #
            #$BPsignature  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type, $BPName) $Level)
            #$BPAttribute = Write-MCHelpPropertyAttribute -Mandatory "false" -HelpMessage $BodyProperty.Description `
            #    -Position $BodyPositionInt -ParameterSetName "NoBody" -Level $Level
            #
            #$BodyPositionInt++
            #
            #$BPText = $BPSummary,$BPAttribute,$BPsignature -join "`r`n"
            #$PropertyTexts.Add($BPText) | Out-Null

            
        }
    }

    foreach ($Key in $ParameterSets.Keys) {

        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase","AuthenticatedCmdletBase") -contains $Method.Api.CmdletBaseType) {
            $P = New-Object ApiMethodProperty
            $P.Name = "GAuthId"
            $P.Description = "The GAuthId representing the gShell auth credentials this cmdlet should use to run."
            $P.Required = $false
            $P.Type = "string"

            $ParameterSets[$Key].Add($P) | Out-Null
        }

        if (@("StandardQueryParametersBase","ServiceAccountCmdletBase") -contains $Method.Api.CmdletBaseType) {
            $P = New-Object ApiMethodProperty
            $P.Name = "TargetUserEmail"
            $P.Description = "The email account to be targeted by the service account."
            $P.Required = $false
            $P.Type = "string"

            $ParameterSets[$Key].Add($P) | Out-Null
        }
    }

    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
    } elseif ($Method.SupportsMediaDownload -eq $true) {
        $DefaultParamSet = "Default"
    } else {
        $DefaultParamSet = "__AllParameterSets"
    }

    Write-MCHelpSyntaxParams $Verb $Noun $DefaultParamSet $ParameterSets[$DefaultParamSet] ([ref]$x)
    
    foreach ($ParamSetName in ($ParameterSets.Keys | where {$_ -ne $DefaultParamSet})) {
        Write-MCHelpSyntaxParams $Verb $Noun $ParamSetName $ParameterSets[$ParamSetName] ([ref]$x)
    }

}

#writes the method parameters for within the method call
function Write-MCHelpMethodCallParams ($Method, [ref]$xmlWriter, $Level=0, [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader) {
    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.Parameters){
        if ($P.Required -eq $true){
            Add-String $Params $P.Name
        }
    }

    if ($AsMediaDownloader -eq $true) {
        $P = Get-MediaDownloadProperty $Method

        Add-String $Params $P.Name
    }

    if ($AsMediaUploader -eq $true) {
        $P = Get-MediaUploadProperty $Method

        Add-String $Params $P.Name
        Add-String $Params "ContentType"

        $MediaUploadProperties = "MediaUpload"
    }

    if (($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0) {
        $PropertiesObjectVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $MediaUploadProperties
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
function Write-MCHelpMethodPropertiesObject ($Method, [ref]$xmlWriter, $Level=0, [bool]$AsMediaUploader) {
    if (($Method.Parameters | where {$_.Required -eq $false -and $_.ShouldIncludeInTemplates -eq $true}).Count -gt 0) {
        
        if ($AsMediaUploader -eq $true){
            $MediaUpload = "MediaUpload"
        }
        $PropertiesObjectVarName = "{0}{1}{2}Properties" -f $Method.Resource.NameLower, $Method.Name, $MediaUpload
        $PropertiesObjectFullName = "{0}.{1}.{2}{3}{4}Properties" -f `
                    ($Api.Name + "ServiceWrapper"), (Get-ParentResourceChain $Method), `
                    $Method.Resource.Name, $Method.Name, $MediaUpload
    
        $PropertiesObjectParameters = New-Object System.Collections.ArrayList

        foreach ($P in $Method.Parameters) {
            if ($P.Required -eq $False -and $P.ShouldIncludeInTemplates -eq $true) {
                if ($AsMediaUploader) {
                    $StrippedName = $P.Name.Replace($MediaUpload, "")
                } else {
                    $StrippedName = $P.Name
                }

                Add-String $PropertiesObjectParameters ("    {0} = this.{1}" -f $StrippedName, $P.Name)
            }
        }

        $PropertiesObjectParametersText = $PropertiesObjectParameters -join ",`r`n{%T}        "

        $ParametersObj = @"
`r`n{%T}        var $PropertiesObjectVarName = new $PropertiesObjectFullName()
{%T}        {
{%T}        $PropertiesObjectParametersText
{%T}        };

"@
        $ParametersObj = Wrap-Text (Set-Indent $ParametersObj $Level)
        return $ParametersObj
    }
}

function Write-MCHelpUploadMethod ($Method, [ref]$xmlWriter, $Level=0) {
    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
    $ParentResourceChainLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceName = $Method.Resource.Name
    
    $Verb = Get-McVerb $Method.Name
    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
    $CmdletBase = $Method.Resource.Api.Name + "Base"
    
    $MethodName = $Method.Name
    $MethodChainLower = $ParentResourceChainLower, $MethodName -join "."
    
    #Determine defeault param set name
    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
    } else {
        $DefaultParamSet = "Default"
    }

    $CmdletAttribute = Write-MCHelpAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
    $Properties = Write-MCHelpMediaUploadProperties $Method ($Level+1)
    $MethodCallParams = Write-MCHelpMethodCallParams $Method
    
    if ($Method.ReturnType.Type -ne "void") {
        $WriteObjectOpen = "WriteObject("
        $WriteObjectClose = ")"
    }

    $PropertyObject = Write-MCHelpMethodPropertiesObject $Method ($Level+2)
    $MediaPropertyObject = Write-MCHelpMethodPropertiesObject $Method.UploadMethod ($Level+2) -AsMediaUploader $true

    $MethodCallLine = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"

    if ($Method.UploadMethod.ReturnType.Type -ne "void") {
        $MediaWriteObjectOpen = "WriteObject("
        $MediaWriteObjectClose = ")"
    }

    $MediaMethodCallParams = Write-MCHelpMethodCallParams $Method -AsMediaUploader $true

    #$P = Get-MediaUploadProperty $Method

    #$ParamSetName = $P.Name

    if ($Method.HasBodyParameter -eq $true) {
        
        $BodyProperties = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties `
            | where Name -ne "ETag"))
        {
            Add-String $BodyProperties ("{{%T}}                    {0} = this.{0}" -f $BodyProperty.Name)
        }
        $BodyProperties = $BodyProperties -join ",`r`n"

        $BodyPropertyType = $Method.BodyParameter.Type

        $BodyParameterSets = @"
{%T}            if (ParameterSetName.EndsWith("NoBody"))
{%T}            {
{%T}                Body = new $BodyPropertyType()
{%T}                {
$BodyProperties
{%T}                };
{%T}            }
"@
    }

    $text = @"
{%T}$CmdletAttribute
{%T}public class $CmdletCommand : $CmdletBase
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {
{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
{%T}        {
$BodyParameterSets
{%T}            if (ParameterSetName.StartsWith("Media"))
{%T}            {
$MediaPropertyObject
{%T}                $MediaWriteObjectOpen $MethodChainLower($MediaMethodCallParams)$MediaWriteObjectClose;
{%T}            }
{%T}            else
{%T}            {
$PropertyObject
{%T}                $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;
{%T}            }
{%T}        }
{%T}    }
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

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

    if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {

    } else {
        Write-MCHelpProperties $Method $Verb $Noun -xmlWriter ([ref]$x)
    }

    #end command:syntax
    $x.WriteEndElement()


#    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
#    $ParentResourceChainLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
#    $ResourceName = $Method.Resource.Name
#    
#    $Verb = Get-McVerb $Method.Name
#    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
#    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
#    $CmdletBase = $Method.Resource.Api.Name + "Base"
#    
#    $MethodName = $Method.Name
#    $MethodChainLower = $ParentResourceChainLower, $MethodName -join "."
#    
#    if ($Method.HasBodyParameter -eq $true) {
#        $DefaultParamSet = "WithBody"
#    } elseif ($Method.SupportsMediaDownload -eq $true) {
#        $DefaultParamSet = "Default"
#    }
#
#    $CmdletAttribute = Write-MCHelpAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
#    if ($Method.SupportsMediaDownload -eq $true) {
#        $Properties = Write-MCMediaDownloadProperties $Method ($Level+1)
#    } else {
#        $Properties = Write-MCHelpProperties $Method ($Level+1)
#    }
#    $MethodCallParams = Write-MCHelpMethodCallParams $Method
#    
#    if ($Method.ReturnType.Type -ne "void") {
#        $WriteObjectOpen = "WriteObject("
#        $WriteObjectClose = ")"
#    }
#
#    $PropertyObject = Write-MCHelpMethodPropertiesObject $Method $Level
#    
#    if ($Method.HasBodyParameter -eq $true) {
#        
#        $BodyProperties = New-Object System.Collections.ArrayList
#        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties `
#            | where Name -ne "ETag"))
#        {
#            Add-String $BodyProperties ("{{%T}}                    {0} = this.{0}" -f $BodyProperty.Name)
#        }
#        $BodyProperties = $BodyProperties -join ",`r`n"
#
#        $BodyPropertyType = $Method.BodyParameter.Type
#
#        $BodyParameterSets = @"
#{%T}        if (ParameterSetName.EndsWith("NoBody"))
#{%T}        {
#{%T}            Body = new $BodyPropertyType()
#{%T}            {
#$BodyProperties
#{%T}            };
#{%T}        }
#{%T}
#"@
#    }
#
#    $MethodCall = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"
#
#    if ($Method.SupportsMediaDownload) {
#        $MediaMethodCallParams = Write-MCHelpMethodCallParams $Method -AsMediaDownloader `
#            $Method.SupportsMediaDownload
#
#        $MediaMethodCall = "{%T}                $MethodChainLower($MediaMethodCallParams);"
#
#        $MethodCallBlock = @"
#{%T}            if (ParameterSetName.StartsWith("Media"))
#{%T}            {
#$MediaMethodCall
#{%T}            }
#{%T}            else
#{%T}            {
#    $MethodCall
#{%T}            }
#"@
#    } else {
#        $MethodCallBlock = $MethodCall
#    }
#    
#    $text = @"
#{%T}$CmdletAttribute
#{%T}public class $CmdletCommand : $CmdletBase
#{%T}{
#{%T}    #region Properties
#
#$Properties
#
#{%T}    #endregion
#
#{%T}    protected override void ProcessRecord()
#{%T}    {$PropertyObject
#$BodyParameterSets
#{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
#{%T}        {
#$MethodCallBlock
#{%T}        }
#{%T}    }
#{%T}}
#"@
#
#    $text = Wrap-Text (Set-Indent $text -TabCount $Level)
#
#    return $text

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

function Write-MCHelp ($Api, $Path) {
    
    

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

$Path = "$env:USERPROFILE\desktop\xmltest2.xml"

write-mchelp -Api $api -Path $Path