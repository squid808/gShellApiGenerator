$VerbsDict = @{
    "Add"= "VerbsCommon.Add"
    "Clear"= "VerbsCommon.Clear"
    "Close"= "VerbsCommon.Close"
    "Copy"= "VerbsCommon.Copy"
    "Enter"= "VerbsCommon.Enter"
    "Exit"= "VerbsCommon.Exit"
    "Find"= "VerbsCommon.Find"
    "Format"= "VerbsCommon.Format"
    "Get"= "VerbsCommon.Get"
    "Hide"= "VerbsCommon.Hide"
    "Join"= "VerbsCommon.Join"
    "Lock"= "VerbsCommon.Lock"
    "Move"= "VerbsCommon.Move"
    "New"= "VerbsCommon.New"
    "Open"= "VerbsCommon.Open"
    "Pop"= "VerbsCommon.Pop"
    "Push"= "VerbsCommon.Push"
    "Redo"= "VerbsCommon.Redo"
    "Remove"= "VerbsCommon.Remove"
    "Rename"= "VerbsCommon.Rename"
    "Reset"= "VerbsCommon.Reset"
    "Search"= "VerbsCommon.Search"
    "Select"= "VerbsCommon.Select"
    "Set"= "VerbsCommon.Set"
    "Show"= "VerbsCommon.Show"
    "Skip"= "VerbsCommon.Skip"
    "Split"= "VerbsCommon.Split"
    "Step"= "VerbsCommon.Step"
    "Switch"= "VerbsCommon.Switch"
    "Undo"= "VerbsCommon.Undo"
    "Unlock"= "VerbsCommon.Unlock"
    "Watch"= "VerbsCommon.Watch"

    "Connect"= "VerbsCommunications.Connect"
    "Disconnect"= "VerbsCommunications.Disconnect"
    "Read"= "VerbsCommunications.Read"
    "Receive"= "VerbsCommunications.Receive"
    "Send"= "VerbsCommunications.Send"
    "Write"= "VerbsCommunications.Write"

    "Backup"= "VerbsData.Backup"
    "Checkpoint"= "VerbsData.Checkpoint"
    "Compare"= "VerbsData.Compare"
    "Compress"= "VerbsData.Compress"
    "Convert"= "VerbsData.Convert"
    "ConvertFrom"= "VerbsData.ConvertFrom"
    "ConvertTo"= "VerbsData.ConvertTo"
    "Dismount"= "VerbsData.Dismount"
    "Edit"= "VerbsData.Edit"
    "Expand"= "VerbsData.Expand"
    "Export"= "VerbsData.Export"
    "Group"= "VerbsData.Group"
    "Import"= "VerbsData.Import"
    "Initialize"= "VerbsData.Initialize"
    "Limit"= "VerbsData.Limit"
    "Merge"= "VerbsData.Merge"
    "Mount"= "VerbsData.Mount"
    "Out"= "VerbsData.Out"
    "Publish"= "VerbsData.Publish"
    "Restore"= "VerbsData.Restore"
    "Save"= "VerbsData.Save"
    "Sync"= "VerbsData.Sync"
    "Unpublish"= "VerbsData.Unpublish"
    "Update"= "VerbsData.Update"

    "Debug"= "VerbsDiagnostic.Debug"
    "Measure"= "VerbsDiagnostic.Measure"
    "Ping"= "VerbsDiagnostic.Ping"
    "Repair"= "VerbsDiagnostic.Repair"
    "Resolve"= "VerbsDiagnostic.Resolve"
    "Test"= "VerbsDiagnostic.Test"
    "Trace"= "VerbsDiagnostic.Trace"

    "Approve"= "VerbsLifecycle.Approve"
    "Assert"= "VerbsLifecycle.Assert"
    "Complete"= "VerbsLifecycle.Complete"
    "Confirm"= "VerbsLifecycle.Confirm"
    "Deny"= "VerbsLifecycle.Deny"
    "Disable"= "VerbsLifecycle.Disable"
    "Enable"= "VerbsLifecycle.Enable"
    "Install"= "VerbsLifecycle.Install"
    "Invoke"= "VerbsLifecycle.Invoke"
    "Register"= "VerbsLifecycle.Register"
    "Request"= "VerbsLifecycle.Request"
    "Restart"= "VerbsLifecycle.Restart"
    "Resume"= "VerbsLifecycle.Resume"
    "Start"= "VerbsLifecycle.Start"
    "Stop"= "VerbsLifecycle.Stop"
    "Submit"= "VerbsLifecycle.Submit"
    "Suspend"= "VerbsLifecycle.Suspend"
    "Uninstall"= "VerbsLifecycle.Uninstall"
    "Unregister"= "VerbsLifecycle.Unregister"
    "Wait"= "VerbsLifecycle.Wait"

    "Block"= "VerbsSecurity.Block"
    "Grant"= "VerbsSecurity.Grant"
    "Protect"= "VerbsSecurity.Protect"
    "Revoke"= "VerbsSecurity.Revoke"
    "Unblock"= "VerbsSecurity.Unblock"
    "Unprotect"= "VerbsSecurity.Unprotect"

    "Use"= "VerbsOther.Use"
}

#TODO: Consolidate these two functions
function Get-McVerb ($VerbInput) {
    if ($VerbsDict.ContainsKey($VerbInput)) {
        $FullVerb = $VerbsDict[($VerbInput)]
        return $FullVerb.Split(".")[1]
    }

    return $VerbInput
}

function Get-MCAttributeVerb ($VerbInput) {
    if ($VerbsDict.ContainsKey($VerbInput)) {
        return $VerbsDict[($VerbInput)]
    }

    return "`"$VerbInput`""
}

#TODO - fix in to using list?
function Write-MCAttribute ($Method, $Noun, $DefaultParameterSet=$Null) {
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

function Write-MCPropertyAttribute ($Mandatory, $HelpMessage, $Position, $ParameterSetName, $Level = 0) {
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

function Write-MCMediaUploadProperties($Method, $Level=0) {
    
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
            $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level

            Add-String $Attributes $Attribute
        }
        
        #specify the param sets if needed, regardless still increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                if ($KeysToProcess.Count -eq 1) {
                    $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                        $Parameter.Description -Position $Counts[$Key][$SubKey][0] -Level $Level `
                        -ParameterSetName $SubKey

                    Add-String $Attributes $Attribute
                }
                $Counts[$Key][$SubKey][0]++
            }
        }

        $Attributes = $Attributes -join "`r`n"

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attributes,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Now add any methods from the media upload method that weren't used already
    foreach ($Parameter in $UploadParams) {

        if ($MethodParams.Name -contains $Parameter.Name `
            -and (($MethodParams | where Name -eq $Parameter.Name).Type.Type -ne $Parameter.Type.Type)) {
            $Parameter.Name = "MediaUpload" + $Parameter.Name
        }

        if ($MethodParams.Name -notcontains $Parameter.Name) {

            $required = $Parameter.Required.ToString().ToLower()
            
            $Attributes = New-Object System.Collections.ArrayList

            foreach ($SubKey in $Counts["Media"].Keys) {
                $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
                    $Parameter.Description -Position $Counts["Media"][$SubKey][0] -Level $Level `
                    -ParameterSetName $SubKey

                Add-String $Attributes $Attribute
                $Counts["Media"][$SubKey][0]++
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
            $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type.Type, $Parameter.Name) $Level)

            $ParameterText = $summary,$attributes,$declaration -join "`r`n"

            Add-String $ParameterTexts $ParameterText
        }
    }

    #Handle the additional upload methods
    $PMedia = Get-MediaUploadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type.type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Get the content type property
    $Attributes = New-Object System.Collections.ArrayList
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f 'The content type for this file') $Level)
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage 'The content type for this file' `
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
                $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} Body {{ get; set; }}" -f $Method.BodyParameter.Type.Type) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

function Write-MCMediaDownloadProperties($Method, $Level=0) {
    
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
        $attribute = Write-MCPropertyAttribute -Mandatory $required -HelpMessage `
            $Parameter.Description -Position $Counts["NoMedia"][$SubKey][0] -Level $Level
        
        #increment the counts 
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in $Counts[$Key].Keys) {
                $Counts[$Key][$SubKey][0]++
            }
        }

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Parameter.Description)) $Level)
        $declaration  = Wrap-Text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Parameter.Type.Type, $Parameter.Name) $Level)

        $ParameterText = $summary,$attribute,$declaration -join "`r`n"

        Add-String $ParameterTexts $ParameterText
    }

    #Handle the additional download methods
    $PMedia = Get-MediaDownloadProperty -Method $Method

    $Attributes = New-Object System.Collections.ArrayList
    foreach ($SubKey in $Counts["Media"].Keys) {
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $PMedia.Description `
            -Position $Counts["Media"][$SubKey][0] -Level $Level -ParameterSetName $SubKey
        Add-String $Attributes $Attribute
        $Counts["Media"][$SubKey][0]++
    }
    $Attributes = $Attributes -join "`r`n"
    $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $PMedia.Description)) $Level)
    $declaration  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $PMedia.Type.Type, $PMedia.Name) $Level)
    $ParameterText = $summary,$Attributes,$declaration -join "`r`n"
    Add-String $ParameterTexts $ParameterText

    #Now handle the body, if any
    if ($Method.HasBodyParameter -eq $true) {
        
        $Attributes = New-Object System.Collections.ArrayList
        foreach ($Key in $KeysToProcess) {
            foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*WithBody"})) {
                $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Method.BodyParameter.Description `
                    -Position $Counts[$Key][$SubKey][0] -ParameterSetName $SubKey -Level $Level
                Add-String $Attributes $Attribute
                $Counts[$Key][$SubKey][0]++
            }
        }
        $Attributes = $Attributes -join "`r`n"
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Method.BodyParameter.Description)) $Level)
        $declaration  = wrap-text (set-indent ("{{%T}}public {0} Body {{ get; set; }}" -f $Method.BodyParameter.Type.Type) $Level)
            
        $BodyText = $summary,$attributes,$declaration -join "`r`n"
        Add-String $ParameterTexts $BodyText

        #Now write the non-body options
        $BodyAttributes = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name `
                -or $Method.UploadMethod.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            $Attributes = New-Object System.Collections.ArrayList
            foreach ($Key in $KeysToProcess) {
                foreach ($SubKey in ($Counts[$Key].Keys | where {$_ -like "*NoBody"})) {
                    $Attribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage `
                        $BodyProperty.Description -Position $Counts[$Key][$SubKey][0] `
                        -ParameterSetName $SubKey -Level $Level

                    Add-String $Attributes $Attribute
                    $Counts[$Key][$SubKey][0]++
                }
            }
            $Attributes = $Attributes -join "`r`n"

            $summary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            $declaration  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type.Type, $BPName) $Level)
            
            $Text = $summary,$Attributes,$declaration -join "`r`n"
            Add-String $ParameterTexts $Text
        }
    }

    $Properties = $ParameterTexts -join "`r`n`r`n"

    return $Properties
}

#write the parameters for the cmdlet
function Write-MCProperties ($Method, $Level=0) {
    $PropertyTexts = New-Object System.Collections.ArrayList
    
    $StandardPositionInt = 0
    $BodyPositionInt = 0

    #build, indent and wrap the pieces separately to allow for proper wrapping of comments and long strings
    foreach ($Property in ($Method.Parameters | where { ` #$_.Required -eq $true -and `
            $_.Name -ne "Body" -and $_.ShouldIncludeInTemplates -eq $true})) {

        $summary = Wrap-Text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)

        $required = $Property.Required.ToString().ToLower()

        $attributes = Write-MCPropertyAttribute -Mandatory $required -HelpMessage $Property.Description `
            -Position $StandardPositionInt -Level $Level
        $signature  = wrap-text (set-indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $Property.Type.Type, $Property.Name) $Level)

        $PropertyText = $summary,$attributes,$signature -join "`r`n"

        $PropertyTexts.Add($PropertyText) | Out-Null
        $StandardPositionInt++
    }
    
    if ($Method.HasBodyParameter -eq $true) {
        
        $summary = wrap-text (set-indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $Property.Description)) $Level)
        $signature  = wrap-text (set-indent ("{{%T}}public {0} Body {{ get; set; }}" -f $Method.BodyParameter.Type.Type) $Level)
        $attribute = Write-MCPropertyAttribute -Mandatory "true" -HelpMessage $Property.Description `
            -Position $StandardPositionInt -ParameterSetName "WithBody" -Level $Level
            
        $BodyText = $summary,$attribute,$signature -join "`r`n"
        $PropertyTexts.Add($BodyText) | Out-Null

        $BodyPositionInt = $StandardPositionInt
        $StandardPositionInt++

        $BodyAttributes = New-Object System.Collections.ArrayList

        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties | where Name -ne "ETag")) {
            
            $BPName = $BodyProperty.Name

            if ($Method.Parameters.Name -contains $BodyProperty.Name) {
                $BPName = $Method.BodyParameter.SchemaObject.Name + $BodyProperty.Name
            }

            $BPsummary = wrap-text (Set-Indent ("{{%T}}/// <summary> {0} </summary>" -f (Format-CommentString $BodyProperty.Description)) $Level)
            
            $BPsignature  = wrap-text (Set-Indent ("{{%T}}public {0} {1} {{ get; set; }}" -f $BodyProperty.Type.Type, $BPName) $Level)
            $BPAttribute = Write-MCPropertyAttribute -Mandatory "false" -HelpMessage $BodyProperty.Description `
                -Position $BodyPositionInt -ParameterSetName "NoBody" -Level $Level

            $BodyPositionInt++

            $BPText = $BPSummary,$BPAttribute,$BPsignature -join "`r`n"
            $PropertyTexts.Add($BPText) | Out-Null
        }
    }

    $Text = $PropertyTexts -join "`r`n`r`n"

    return $Text
}

#writes the method parameters for within the method call
function Write-MCMethodCallParams ($Method, $Level=0, [bool]$AsMediaDownloader=$false, [bool]$AsMediaUploader) {
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
function Write-MCMethodPropertiesObject ($Method, $Level=0, [bool]$AsMediaUploader) {
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

function Write-MCUploadMethod ($Method, $Level=0) {
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

    $CmdletAttribute = Write-MCAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
    $Properties = Write-MCMediaUploadProperties $Method ($Level+1)
    $MethodCallParams = Write-MCMethodCallParams $Method
    
    if ($Method.ReturnType.Type.Type -ne "void") {
        $WriteObjectOpen = "WriteObject("
        $WriteObjectClose = ")"
    }

    $PropertyObject = Write-MCMethodPropertiesObject $Method ($Level+2)
    $MediaPropertyObject = Write-MCMethodPropertiesObject $Method.UploadMethod ($Level+2) -AsMediaUploader $true

    $MethodCallLine = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"

    if ($Method.UploadMethod.ReturnType.Type.Type -ne "void") {
        $MediaWriteObjectOpen = "WriteObject("
        $MediaWriteObjectClose = ")"
    }

    $MediaMethodCallParams = Write-MCMethodCallParams $Method -AsMediaUploader $true

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

        $BodyPropertyType = $Method.BodyParameter.Type.Type

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

function Write-MCMethod ($Method, $Level=0) {
    $ParentResourceChainNoJoin = Get-ParentResourceChain -MethodOrResource $Method -JoinChar ""
    $ParentResourceChainLower = Get-ParentResourceChain -MethodOrResource $Method -UpperCase $false
    $ResourceName = $Method.Resource.Name
    
    $Verb = Get-McVerb $Method.Name
    $Noun = "G" + $Method.Api.Name + (ConvertTo-FirstUpper $Method.Api.Version) + $ParentResourceChainNoJoin
    $CmdletCommand = "{0}{1}Command" -f $Verb,$Noun
    $CmdletBase = $Method.Resource.Api.Name + "Base"
    
    $MethodName = $Method.Name
    $MethodChainLower = $ParentResourceChainLower, $MethodName -join "."
    
    if ($Method.HasBodyParameter -eq $true) {
        $DefaultParamSet = "WithBody"
    } elseif ($Method.SupportsMediaDownload -eq $true) {
        $DefaultParamSet = "Default"
    }

    $CmdletAttribute = Write-MCAttribute -Method $Method -Noun $Noun -DefaultParameterSet $DefaultParamSet
    if ($Method.SupportsMediaDownload -eq $true) {
        $Properties = Write-MCMediaDownloadProperties $Method ($Level+1)
    } else {
        $Properties = Write-MCProperties $Method ($Level+1)
    }
    $MethodCallParams = Write-MCMethodCallParams $Method
    
    if ($Method.ReturnType.Type.Type -ne "void") {
        $WriteObjectOpen = "WriteObject("
        $WriteObjectClose = ")"
    }

    $PropertyObject = Write-MCMethodPropertiesObject $Method $Level
    
    if ($Method.HasBodyParameter -eq $true) {
        
        $BodyProperties = New-Object System.Collections.ArrayList
        foreach ($BodyProperty in ($Method.BodyParameter.SchemaObject.Properties `
            | where Name -ne "ETag"))
        {
            Add-String $BodyProperties ("{{%T}}                    {0} = this.{0}" -f $BodyProperty.Name)
        }
        $BodyProperties = $BodyProperties -join ",`r`n"

        $BodyPropertyType = $Method.BodyParameter.Type.Type

        $BodyParameterSets = @"
{%T}        if (ParameterSetName.EndsWith("NoBody"))
{%T}        {
{%T}            Body = new $BodyPropertyType()
{%T}            {
$BodyProperties
{%T}            };
{%T}        }
{%T}
"@
    }

    $MethodCall = "{%T}            $WriteObjectOpen $MethodChainLower($MethodCallParams)$WriteObjectClose;"

    if ($Method.SupportsMediaDownload) {
        $MediaMethodCallParams = Write-MCMethodCallParams $Method -AsMediaDownloader `
            $Method.SupportsMediaDownload

        $MediaMethodCall = "{%T}                $MethodChainLower($MediaMethodCallParams);"

        $MethodCallBlock = @"
{%T}            if (ParameterSetName.StartsWith("Media"))
{%T}            {
$MediaMethodCall
{%T}            }
{%T}            else
{%T}            {
    $MethodCall
{%T}            }
"@
    } else {
        $MethodCallBlock = $MethodCall
    }
    
    $text = @"
{%T}$CmdletAttribute
{%T}public class $CmdletCommand : $CmdletBase
{%T}{
{%T}    #region Properties

$Properties

{%T}    #endregion

{%T}    protected override void ProcessRecord()
{%T}    {$PropertyObject
$BodyParameterSets
{%T}        if (ShouldProcess("$Noun $ResourceName", "$Verb-$Noun"))
{%T}        {
$MethodCallBlock
{%T}        }
{%T}    }
{%T}}
"@

    $text = Wrap-Text (Set-Indent $text -TabCount $Level)

    return $text

}

function Write-MCResource ($Resource) {

    $MethodTexts = New-Object System.Collections.ArrayList
    $ParentResourceChain = Get-ParentResourceChain -MethodOrResource $Resource
    if (-not [string]::IsNullOrWhiteSpace($ParentResourceChain)) {
        $ParentResourceChain += "."
    }
    $NameSpace = "gShell.Cmdlets." + $Resource.Api.Name + "." + $ParentResourceChain + $Resource.Name

    foreach ($Method in $Resource.Methods) {
        if ($Method.UploadMethod -ne $null -and $Method.UploadMethod.SupportsMediaUpload -eq $true) {
            $MText = Write-MCUploadMethod $Method -Level 1
        } else {
            $MText = Write-MCMethod $Method -Level 1
        }

        Add-String $MethodTexts $MText
    }

    $MethodBlock = $MethodTexts -join "`r`n`r`n"

    $text = @"
namespace $NameSpace {
$MethodBlock
}
"@

    return $text
}

function Write-MCResources ($Resources) {
#should return with each resource in its own namespace at the same level?

    $ResourceTexts = New-Object System.Collections.ArrayList

    foreach ($Resource in $Resources) {
        $RText = Write-MCResource $Resource
        Add-String $ResourceTexts $RText

        if ($Resource.ChildResources.Count -gt 0) {
            $ChildResourcesText = Write-MCResources $Resource.ChildResources
            Add-String $ResourceTexts $ChildResourcesText
        }
    }

    $ResourcesBlock = $ResourceTexts -join "`r`n`r`n"

    return $ResourcesBlock

}

function Write-MC ($Api) {
    
    $Resources = Write-MCResources $Api.Resources

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

    return $text
}