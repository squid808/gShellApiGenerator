$BuildDir = "$env:windir\Microsoft.NET\Framework\v4.0.30319"
$BuildExe = "$BuildDir\MSBuild.exe"


function New-PackagesConfig ($LibraryIndex, $DependenciesChain, $BuildProjectPath) {

    $Packages = New-Object system.collections.arraylist

    $packageFormatString = '  <package id="{0}" version="{1}" targetFramework="net451" />'

    $Exclusions = @("System.Net.Http", "System.Management.Automation.dll","gShell.Main")

    foreach ($D in $DependenciesChain.GetEnumerator()) {
        if ($Exclusions -notcontains $D.Name) {
            Add-String $Packages ($packageFormatString -f $D.Name, $D.Value)
        }
    }

    Add-String $Packages ($packageFormatString -f "System.Management.Automation.dll", "10.0.10586.0")

    $PackagesXml = $Packages -join "`r`n"

    $packagesText = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
{0}
</packages>
'@ -f $PackagesXml

    $packagesText | Out-File -FilePath ([System.IO.Path]::Combine($BuildProjectPath, "packages.config")) -Encoding utf8 -Force
}

function Get-CsProjBuildFiles ($BuildProjectPath) {
    $FilesList = Get-ChildItem $BuildProjectPath -Recurse -Filter "*.cs"| select -ExpandProperty fullname `
        | where {$_ -notlike "*\obj\*"}

    $Files = New-Object system.collections.arraylist

    foreach ($File in $FilesList) {
        Add-String $Files ("    <Compile Include = `"" + $File.Replace(($BuildProjectPath+"\"),"") + "`" />")
    }

    $FilesText = $Files -join "`r`n"

    return $FilesText
}

function Get-CsProjReferences ($LibraryIndex, $DependenciesChain) {
    
    $Dependencies = New-Object system.collections.arraylist

    $latestGoogleAuthVersion = $LibraryIndex.GetLibVersionLatestName("Google.Apis.Auth")

    $Exclusions = @("System.Net.Http", "System.Management.Automation.dll")

    foreach ($D in $DependenciesChain.GetEnumerator()) {
        if ($Exclusions -notcontains $D.Name) {
            $Version = [System.Reflection.Assembly]::LoadFrom($LibraryIndex.GetLibVersion($D.Name, $D.Value).dllPath).GetName().Version.ToString()
            
            $HintPath1 = Write-CSPReferenceHintPath -Name $D.Name -Version $D.Value -IsConditional $true
            $HintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\{1}\{0}.dll" -f $D.Name, $D.Value) -IsConditional $true
            $ReferenceText = Write-CSPReference $D.Name $Version $HintPath1 $HintPath2       

            Add-String $Dependencies $ReferenceText
        }
    }

    #TODO: Manually write this out - will it change? Only if MS decides to upload their own version I guess. Who am I talking to? Does this mean I've cracked?
    $SysAutoName = "System.Management.Automation"
    $SysAutoVersion = "10.0.10586.0" #note - the version pulled from nuget doesn't have a 0 at the end but it does when restored.
    
    $AutomationHintPath1 = Write-CSPReferenceHintPath -Name $SysAutoName -Version $SysAutoVersion -IsConditional $true
    $AutomationHintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\10.0.10586\{0}.dll" -f $SysAutoName, $SysAutoVersion) -IsConditional $true
    Add-String $Dependencies (Write-CSPReference $SysAutoName "3.0.0.0" -HintPath1 $AutomationHintPath1 -HintPath2 $AutomationHintPath2 -Private $true)
    
    $DependenciesText = $Dependencies -join "`r`n"

    return $DependenciesText
}

function New-AssemblyInfoFile ($AssemblyTitle, $AssemblyDescription, $AssemblyVersion, $BuildProjectPath) {
    $Year = Get-Date -Format "yyyy"

    $AssemblyText = @"
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

// General Information about an assembly is controlled through the following 
// set of attributes. Change these attribute values to modify the information
// associated with an assembly.
[assembly: AssemblyTitle("$AssemblyTitle")]
[assembly: AssemblyDescription("$AssemblyDescription")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("Spencer Varney")]
[assembly: AssemblyProduct("gShell")]
[assembly: AssemblyCopyright("Copyright ©  $Year")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

[assembly: AssemblyVersion("$AssemblyVersion")]
[assembly: AssemblyFileVersion("$AssemblyVersion")]
"@

    $AssemblyFolderPath = [System.IO.Path]::Combine($BuildProjectPath, "Properties")
    $AssemblyFilePath = [System.IO.Path]::Combine($AssemblyFolderPath, "AssemblyInfo.cs")

    if (-not (Test-Path $AssemblyFolderPath)) {
        New-Item -Path $AssemblyFolderPath -ItemType "Directory" | Out-Null
    }

    $AssemblyText | Out-File -FilePath $AssemblyFilePath -Encoding utf8 -Force
}

function New-CsProjFile ($LibraryIndex, $DependencyChain, $BuildProjectPath, $Api) {

    $NewGuid = [System.Guid]::NewGuid().ToString("B").ToUpper()
    $RootNamespace = "gShell." + $Api.NameAndVersion
    $AssemblyName = "gShell." + $Api.NameAndVersion
    $BuildFiles = Get-CsProjBuildFiles $BuildProjectPath
    $ProjReferences = Get-CsProjReferences -LibraryIndex $LibraryIndex -DependenciesChain $DependencyChain

    $projText = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <MinimumVisualStudioVersion>10.0</MinimumVisualStudioVersion>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProjectGuid>{0}</ProjectGuid>
    <OutputType>Library</OutputType>
    <AppDesignerFolder>Properties</AppDesignerFolder>
    <RootNamespace>{1}</RootNamespace>
    <AssemblyName>{2}</AssemblyName>
    <TargetFrameworkVersion>v4.5.1</TargetFrameworkVersion>
    <FileAlignment>512</FileAlignment>
    <TargetFrameworkProfile />
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
    <DebugSymbols>true</DebugSymbols>
    <DebugType>full</DebugType>
    <Optimize>false</Optimize>
    <OutputPath>bin\Debug\</OutputPath>
    <DefineConstants>DEBUG;TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
    <Prefer32Bit>false</Prefer32Bit>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
    <DebugType>pdbonly</DebugType>
    <Optimize>true</Optimize>
    <OutputPath>bin\Release\</OutputPath>
    <DefineConstants>TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
    <Prefer32Bit>false</Prefer32Bit>
  </PropertyGroup>
  <ItemGroup>
{3}
  </ItemGroup>
  <ItemGroup>
    <Reference Include="System" />
    <Reference Include="System.Security" />
{4}
  </ItemGroup>
  <ItemGroup>
    <None Include="packages.config" />
  </ItemGroup>
  <ItemGroup />
  <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
  <!-- To modify your build process, add your task inside one of the targets below and uncomment it. 
       Other similar extension points exist, see Microsoft.Common.targets.
  <Target Name="BeforeBuild">
  </Target>
  <Target Name="AfterBuild">
  </Target>
  -->
</Project>
'@ -f $NewGuid, $RootNamespace, $AssemblyName, $BuildFiles,  $ProjReferences

    $projFilePath = [System.IO.Path]::Combine($BuildProjectPath, "$AssemblyName.csproj")

    $projText | Out-File -FilePath $projFilePath -Encoding utf8 -Force
}

function Build-ApiLibrary ($LibraryIndex, [ref]$BuildResultObj, [bool]$Log=$false) {

    $BuildResult = $BuildResultObj.Value

    $LatestAuthVersion = $BuildResult.DependencyChain.'Google.Apis.Auth'

    $gShellVersionToUse = $LibraryIndex.GetLibVersionAll("gShell.Main") | % {`
        if (($_.Value.Dependencies | where {$_.Name -eq "Google.Apis.Auth" -and $_.Versions -like "*1.*"}) -ne $null) { `
            $_.Name `
        }} `
        | sort -Descending | select -First 1

    if ([string]::IsNullOrWhiteSpace($gShellVersionToUse)) {
        throw ("gShell version $LatestAuthVersion not found for {0}" -f $BuildResult.Api.RootNameSpace)
    }

    $gShellDependencyChain = $LibraryIndex.GetLibVersionDependencyChain("gShell.Main", $gShellVersionToUse)

    #sync the dependencies for this gshell version with this api
    foreach ($pair in $gShellDependencyChain.GetEnumerator()) {
        $BuildResult.DependencyChain[$pair.name] = $pair.Value
    }

    #Now we need to generate the files and get the csproj location
    #$dllPath = $LibraryIndex.GetLibVersion($BuildResult.Api.RootNameSpace, $BuildResult.Api.AssemblyVersion).dllPath

    #TODO - move this in to the templating and generation method
    #Now create the meta files
    New-PackagesConfig -LibraryIndex $LibraryIndex -DependenciesChain $BuildResult.DependencyChain -BuildProjectPath `
        $BuildResult.GeneratedProjectPath
        
    New-CsProjFile -LibraryIndex $LibraryIndex -DependencyChain $BuildResult.DependencyChain -BuildProjectPath `
        $BuildResult.GeneratedProjectPath -Api $BuildResult.Api

    #Start here - need the Properties / AssemblyInfo.cs file! Need to update this for gshell too, to update the versions
    New-AssemblyInfoFile -AssemblyTitle ("gShell." + $BuildResult.Api.NameAndVersion) `
        -AssemblyDescription ("PowerShell Client for Google {0} Apis" -f $BuildResult.Api.NameAndVersion) `
        -AssemblyVersion $BuildResult.Api.AssemblyVersion -BuildProjectPath $BuildResult.GeneratedProjectPath

    Log ("Building gShell." + $BuildResult.Api.NameAndVersion) $Log

    $CompileResult = Invoke-MsBuild -Path ([System.IO.Path]::Combine($BuildResult.GeneratedProjectPath, ("gShell." + `
        $BuildResult.Api.NameAndVersion + ".csproj")))

    $BuildResult.BuildSucceeded = $CompileResult.BuildSucceeded
    $BuildResult.BuildMessage = $CompileResult.Message

    if ($BuildResult.BuildSucceeded -eq $true) {
        Log ("Building succeeded") $Log

        $BuildResult.CompiledDirPath = [System.IO.Path]::Combine($BuildResult.GeneratedProjectPath,"bin\Debug\")
    } else {
        Log ("Build failed") $Log
    }
}

#Sets the libsource to local, sets dependencies, dll path,  last version built
function SaveCompiledToLibraryIndex ($ApiName, $Version, $DllLocation, $SourceVersion, $BuildSucceeded, $LibraryIndex, $Dependencies, [bool]$Log = $false) {
    
    #add library
    if (-not $LibraryIndex.HasLib($ApiName)) {
        Log ("$ApiName doesn't exist in the Library Index - adding entry") $Log
        $LibraryIndex.AddLib($ApiName)
    }

    #add version to library
    if (-not $LibraryIndex.HasLibVersion($ApiName, $Version)) {
        Log ("$ApiName doesn't have an entry for version $Version - adding with dependencies") $Log
        $LibraryIndex.AddLibVersion($ApiName, $Version)

    }

    foreach ($Dependency in $Dependencies.GetEnumerator()) {
        if (-not $LibraryIndex.HasLibVersionDependency($ApiName, $Version, $Dependency.Name, $Dependency.Value)) {
            $LibraryIndex.AddLibVersionDependency($ApiName, $Version, $Dependency.Name, $Dependency.Value)
        }
    }

    $LibraryIndex.SetLibSource($ApiName, "Local")

    $LibraryIndex.GetLibVersion($ApiName, $Version)."dllPath" = $DllLocation
    $LibraryIndex.SetLibLastVersionBuilt($ApiName, $Version)
    if ($BuildSucceeded -eq $true) {
        $LibraryIndex.SetLibLastSuccessfulVersionBuilt($ApiName, $Version)
    }
    $LibraryIndex.SetLibraryVersionSourceVersion($ApiName, $Version, $SourceVersion)
    $LibraryIndex.SetLibraryVersionSuccessfulGeneration($ApiName, $Version, $BuildSucceeded)
    $LibraryIndex.Save()
}

function DetermineNextBuildVersion ($GoogleSourceVersion, $LastGshellVersionBuilt, [switch]$AsAlpha) {
    #get the most recent build status
    #if alpha, 
    #if the version is different, do that version
    #if the same, increment
    $GoogleSplit = $GoogleSourceVersion.Split(".")
    if ($GoogleSplit.Length -eq 4) {
        $GoogleVersionArray = @($GoogleSplit[0], ($GoogleSplit[1] + $GoogleSplit[2]), $GoogleSplit[3])
    } else {
        $GoogleVersionArray = @($GoogleSplit[0], $GoogleSplit[1], $GoogleSplit[2])
    }

    if (-not [string]::IsNullOrWhiteSpace($LastGshellVersionBuilt) ) {
        $OldGShellVersion, $OldGShellAlpha = $LastGshellVersionBuilt.Split("-")

        $GShellVersionArray = $OldGShellVersion.Split(".")

        $UpdatedFromGoogle = $false

        for ($i = 0; $i -lt 3; $i++) {
            if ([int]$GoogleVersionArray[$i] -gt [int]$GShellVersionArray[$i]) {
                $NewVersionArray =  $GoogleVersionArray
                $UpdatedFromGoogle = $true
                break
            }
        }
    } else {
        $NewVersionArray =  $GoogleVersionArray
        $UpdatedFromGoogle = $true
    }
    
    if ($UpdatedFromGoogle -eq $False) {
        if ($AsAlpha) {
            if ([string]::IsNullOrWhiteSpace($OldGShellAlpha)) {
                [string]$GShellVersionArray[2] = [int]$GShellVersionArray[2]+ 1
                $NewVersion = ($GShellVersionArray -join ".") + "-alpha01"
            } else {
                if ($LastGshellVersionBuilt -match "(?<=[a-z]+)[\d]+") {
                    $newAlpha = "-alpha" + ([int]$matches[0] + 1).ToString("00")
                    $NewVersion = ($GShellVersionArray -join ".") + $newAlpha
                } else {
                    throw "new alpha could not be determined"
                }
            }
        } else {
            [string]$GShellVersionArray[2] = [int]$GShellVersionArray[2] + 1
            $NewVersion = ($GShellVersionArray -join ".")
        }
    } else {
        $NewVersion = ($NewVersionArray -join ".")
        if ($AsAlpha) {
            $NewVersion += "-alpha01"
        }
    }

    return $NewVersion

}

class BuildResult {
    #The API object used to build this library
    $Api

    #The name of the compiled library, eg gShell.Gmail.v1
    [string]$LibName

    #The version of the compiled library, eg 1.300.1034-alpha01
    [string]$LibVersion
    
    #Did the build compile successfully?
    [bool]$BuildSucceeded

    #The status message for the build
    [string]$BuildMessage

    #The directory path for the generated project
    [string]$GeneratedProjectPath

    #The directory path for the compiled output, generally GeneratedProjectPath/bin/debug
    [string]$CompiledDirPath

    #Is this an alpha build?
    [bool]$IsAlpha

    #The dependency chain for this library
    [hashtable]$DependencyChain

    #Should the generated source code be pushed to git
    [bool]$ShouldPushSourceToGit

    #Should the Wiki be regenerated
    [bool]$ShouldGenerateWiki
    
    #Should the modules wiki page be updated for this api
    [bool]$ShouldUpdateModulesWiki

    #Should the wiki be pushed to git
    [bool]$ShouldPushWikiToGit


}

#TODO: Split this code up so that all it does is build the library and return the result?
#TODO: have a class to store all necessary result information, a counterpart to $Api?
function CheckAndBuildGShellApi ($Api, $RootProjPath, $LibraryIndex, [bool]$Log = $false, [bool]$Force = $false) {
    
    #This is the latest dll version of the google api library that is available
    #$LatestDllVersion = $LibraryIndex.GetLibVersionLatestName($ApiName)
    
    #This is the last version of the google api library that was used to build something
    $LastVersionBuilt = $LibraryIndex.GetLibLastVersionBuilt($Api.ApiName)

    $BuildResult = New-Object BuildResult

    #$RestNameAndVersion = $LibraryIndex.GetLibRestNameAndVersion($ApiName)
    $BuildResult.LibName = "gShell." + (ConvertTo-FirstUpper $RestNameAndVersion)
    $BuildResult.LibVersion = DetermineNextBuildVersion -GoogleSourceVersion $Api.AssemblyVersion `
        -LastGshellVersionBuilt $LibraryIndex.GetLibLastVersionBuilt($BuildResult.LibName) -AsAlpha
    $BuildResult.GeneratedProjectPath = [System.IO.Path]::Combine($RootProjPath, $BuildResult.LibName)

    if (-not $LibraryIndex.HasLib($Api.ApiName) -or $LastVersionBuilt -eq $null `
        -or $LastVersionBuilt -ne $Api.AssemblyVersion -or $Force) {

        Log ("{0} {1} either doesn't exist or needs to be updated to {2}." -f $BuildResult.LibName, `
            $LastVersionBuilt, $Api.AssemblyVersion) $Log

        ##TODO: make $JsonRootPath global?
        #$JsonFileInfo = Get-MostRecentJsonFile -Path ([System.IO.Path]::Combine($JsonRootPath, $RestNameAndVersion))
        #
        #$RestJson = Get-Content $JsonFileInfo.FullName | ConvertFrom-Json
        #
        ##TODO: Move API out of here and add it directly to the main program - along with json file bits
        $BuildResult.Api = Create-TemplatesFromDll -LibraryIndex $LibraryIndex -Api $Api `
            -OutPath $BuildResult.GeneratedProjectPath -RestJson $RestJson -Log $Log

        $BuildResult.DependencyChain = $LibraryIndex.GetLibVersionDependencyChain($Api.ApiName, $Api.AssemblyVersion)

        #TODO - Almost all of this info should be on the $Api object - api name, dll version. Fix it.
        #First, try to build
        Build-ApiLibrary -LibraryIndex $LibraryIndex -BuildResultObj ([ref]$BuildResult) -Log $Log

        if ($BuildResult.BuildSucceeded -eq $true) {            
            
            #TODO - move this out to a controller method - or maybe in to the generation?
            Log "Building Psd1 file" $Log
            Write-ModuleManifest -Api $Api -Version $BuildResult.LibVersion -ProjectRoot $BuildResult.GeneratedProjectPath

            Log "Building Help XML file" $Log
            
            Write-MCHelp -Api $Api -ApiName $BuildResult.LibName -OutPath $BuildResult.GeneratedProjectPath

            Log ("Copying the compiled $gShellApiName.dll file to the Library Index path") $Log

            #copy the file to the library path. 
            $LibraryRootPath = [System.IO.Path]::GetDirectoryName($LibraryIndex.RootPath)
            $NewDllFolderPath = [System.IO.Path]::Combine($LibraryRootPath, $BuildResult.LibName, `
                $BuildResult.LibVersion)
            $NewDllFilePath = [System.IO.Path]::Combine($NewDllFolderPath, ($BuildResult.LibName + ".dll"))

            if (-not (Test-Path $NewDllFolderPath)) {
                New-Item -Path $NewDllFolderPath -ItemType "Directory" | Out-Null
            }

            #TODO - update this to have the proper files
            dir $BuildResult.CompiledDirPath | where {$_.BaseName -like ($BuildResult.LibName + "*") -and `
                $_.Extension -ne ".pdb"} | % {Copy-Item -Path $_.FullName -Destination $NewDllFolderPath `
                | Out-Null }

            #TODO - move this out of this function? ALSO, make sure the proper version built is set on the google library!
            #update the library
            $LibraryIndex.SetLibLastVersionBuilt($Api.ApiName, $Api.AssemblyVersion)
            SaveCompiledToLibraryIndex -ApiName $BuildResult.LibName -Version $BuildResult.LibVersion -DllLocation $NewDllFilePath `
                -SourceVersion $Api.AssemblyVersion -BuildSucceeded $true -LibraryIndex $LibraryIndex -Dependencies $BuildResult.DependencyChain -Log $Log
            
        } else {
            SaveCompiledToLibraryIndex -ApiName $BuildResult.LibName -Version $BuildResult.LibVersion `
                -SourceVersion $Api.AssemblyVersion -BuildSucceeded $false -LibraryIndex $LibraryIndex -Dependencies $BuildResult.DependencyChain -Log $Log
        }
    } else {
        Log ("$gShellApiName $LastVersionBuilt appears to be up to date") $Log
    }

    return $BuildResult
}