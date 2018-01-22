function Write-CSPReferenceHintPath {
    param (
        [Parameter(ParameterSetName = "Created")]
        $Name,
        
        [Parameter(ParameterSetName = "Created")]
        $Version,
        
        [Parameter(ParameterSetName = "Created")]
        $TargetFramework = "net45",

        [Parameter(ParameterSetName = "Provided")]
        $HintPath,

        $IsConditional = $false
    )

    if ($PSCmdlet.ParameterSetName -eq "Created") {
        $Path = "packages\$Name.$Version\lib\$TargetFramework\$Name.dll"
    } else {
        $Path = $HintPath
    }

    if ($IsConditional -eq $true) {
        $Folder = [System.IO.Path]::GetDirectoryName($Path)
        $Conditional = " Condition=`"Exists('$Folder')`""
    }

    $HintTag = "      <HintPath$Conditional>$Path</HintPath>"

    return $HintTag
}

function Write-CSPReference($Name, $Version, $HintPath1, $HintPath2 = $null, $Private = $null) {

    if ($private -ne $null) {
        $Private = $Private.ToString()
        $PrivateText = "      <Private>$Private</Private>"
    }

    $text = New-Object system.collections.arraylist

    add-string $text "    <Reference Include=`"$Name, Version=$Version`">"
    add-string $text $HintPath1
    add-string $text $HintPath2
    add-string $text $PrivateText
    add-string $text "    </Reference>"

    $textBlock = $text -join "`r`n"

    return $textBlock
}

function Write-CSPReferenceTexts($Api, $LibraryIndex) {

    $ReferencesTexts = New-Object system.collections.arraylist

    $ReferenceChain = $LibraryIndex.GetLibVersionDependencyChain($Api.RootNamespace, $LibraryIndex.GetLibVersionLatestName($Api.RootNamespace))

    foreach ($Key in $ReferenceChain.Keys) {
        Add-String $ReferencesTexts (Write-CSPReference $Key $ReferenceChain[$Key])
    }

    $ReferencesTexts = ($ReferencesTexts | Sort) -join "`r`n"

    return $ReferencesTexts
}