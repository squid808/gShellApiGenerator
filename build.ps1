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
    #note - the version pulled from nuget doesn't have a 0 at the end but it does when restored.
    $AutomationHintPath1 = Write-CSPReferenceHintPath -Name $SysAutoName -Version "10.0.10586.0" -IsConditional $true
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

function Build-ApiLibrary ($LibraryIndex, $ApiName, $ApiObj, $LatestDependencyChain, $BuildProjectPath, $LatestDllVersion) {

    $LatestAuthVersion = $LatestDependencyChain.'Google.Apis.Auth'

    $gShellVersionToUse = $LibraryIndex.GetLibVersionAll("gShell.Main") | % {`
        if (($_.Value.Dependencies | where {$_.Name -eq "Google.Apis.Auth" -and $_.Versions -like "*1.*"}) -ne $null) { `
            $_.Name `
        }} `
        | sort -Descending | select -First 1

    if ([string]::IsNullOrWhiteSpace($gShellVersionToUse)) {
        throw "gShell version $LatestAuthVersion not found for $ApiName"
    }

    $gShellDependencyChain = $LibraryIndex.GetLibVersionDependencyChain("gShell.Main", $gShellVersionToUse)

    #sync the dependencies for this gshell version with this api
    foreach ($pair in $gShellDependencyChain.GetEnumerator()) {
        $LatestDependencyChain[$pair.name] = $pair.Value
    }

    #Now we need to generate the files and get the csproj location
    $dllPath = $LibraryIndex.GetLibVersion($ApiName, $LatestDllVersion).dllPath

    #Now create the meta files
    New-PackagesConfig -LibraryIndex $LibraryIndex -DependenciesChain $LatestDependencyChain -BuildProjectPath $BuildProjectPath
        
    New-CsProjFile -LibraryIndex $LibraryIndex -DependencyChain $LatestDependencyChain -BuildProjectPath $BuildProjectPath -Api $Api

    #Start here - need the Properties / AssemblyInfo.cs file! Need to update this for gshell too, to update the versions
    New-AssemblyInfoFile -AssemblyTitle ("gShell." + $Api.NameAndVersion) `
        -AssemblyDescription ("PowerShell Client for Google {0} Apis" -f $Api.NameAndVersion) `
        -AssemblyVersion $LatestDllVersion -BuildProjectPath $BuildProjectPath

    Log ("Building gShell." + $Api.NameAndVersion) $Log

    $BuildResult = Invoke-MsBuild -Path ([System.IO.Path]::Combine($BuildProjectPath, ("gShell." + $Api.NameAndVersion + ".csproj")))

    if ($BuildResult.BuildSucceeded -eq $true) {
        Log ("Building succeeded") $Log
        #return the path to the resulting dll file
        $compiledDllPath = [System.IO.Path]::Combine($BuildProjectPath,"bin\Debug\gShell." + $Api.NameAndVersion + ".dll")
        return $compiledDllPath
    } else {
        Log ("Build failed") $Log
        #todo: throw error and stop process here?
    }
}

function SaveCompiledToLibraryIndex ($ApiName, $Version, $DllLocation, $LibraryIndex, $Dependencies, [bool]$Log = $false) {
    
    if (-not $LibraryIndex.HasLib($ApiName)) {
        Log ("$ApiName doesn't exist in the Library Index - adding entry") $Log
        $LibraryIndex.AddLib($ApiName)
    }

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

    $LibraryIndex.Save()
}

function CheckAndBuildGShellApi ($ApiName, $RootProjPath, $LibraryIndex, [bool]$Log = $false, [bool]$Force = $false) {
    $LatestDllVersion = $LibraryIndex.GetLibVersionLatestName($ApiName)

    $LastVersionBuilt = $LibraryIndex.GetLibLastVersionBuilt($ApiName)

    $RestNameAndVersion = $LibraryIndex.GetLibRestNameAndVersion($ApiName)

    $gShellApiName = "gShell." + (ConvertTo-FirstUpper $RestNameAndVersion)

    if (-not $LibraryIndex.HasLib($ApiName) -or $LastVersionBuilt -eq $null `
        -or $LastVersionBuilt -ne $LatestDllVersion -or $Force) {

        Log ("$gShellApiName $LastVersionBuilt either doesn't exist or needs to be updated to $LatestDllVersion.") $Log

        #TODO: make $JsonRootPath global?
        $JsonFileInfo = Get-MostRecentJsonFile -Path ([System.IO.Path]::Combine($JsonRootPath, $RestNameAndVersion))

        $RestJson = Get-Content $JsonFileInfo.FullName | ConvertFrom-Json

        $BuildProjectPath = [System.IO.Path]::Combine($RootProjPath, ("gShell.$RestNameAndVersion"))

        $Api = Create-TemplatesFromDll -LibraryIndex $LibraryIndex -ApiName $ApiName -ApiFileVersion $LatestDllVersion `
            -OutPath $BuildProjectPath -RestJson $RestJson -Log $Log

        $gShellApiName = "gShell." + $Api.NameAndVersion

        $LatestDependencyChain = $LibraryIndex.GetLibVersionDependencyChain($ApiName, $LatestDllVersion)

        #First, try to build
        $CompiledPath = Build-ApiLibrary -LibraryIndex $LibraryIndex -ApiName $ApiName -ApiObj $Api `
              -LatestDependencyChain $LatestDependencyChain -BuildProjectPath $BuildProjectPath -LatestDllVersion $LatestDllVersion

        if ($CompiledPath -ne $null) {            

            Log "Building Psd1 file" $Log
            Write-ModuleManifest -Api $Api -ProjectRoot $BuildProjectPath

            Log ("Copying the compiled $gShellApiName.dll file to the Library Index path") $Log

            #copy the file to the library path
            $LibraryRootPath = [System.IO.Path]::GetDirectoryName($LibraryIndex.RootPath)
            $NewDllFolderPath = [System.IO.Path]::Combine($LibraryRootPath, $gShellApiName, $LatestDllVersion)
            $NewDllPath = [System.IO.Path]::Combine($NewDllFolderPath, "$gShellApiName.dll")

            if (-not (Test-Path $NewDllFolderPath)) {
                New-Item -Path $NewDllFolderPath -ItemType "Directory" | Out-Null
            }

            Copy-Item -Path $CompiledPath -Destination $NewDllPath | Out-Null

            #update the library
            $LibraryIndex.SetLibLastVersionBuilt($ApiName, $LatestDllVersion)
            SaveCompiledToLibraryIndex -ApiName $gShellApiName -Version $LatestDllVersion -DllLocation $NewDllPath `
                -LibraryIndex $LibraryIndex -Dependencies $LatestDependencyChain -Log $Log
            
        } else {
            #throw some error right?
        }
    } else {
        Log ("$gShellApiName $LastVersionBuilt appears to be up to date") $Log
    }

    return $gShellApiName, $LatestDllVersion
        

        #$gShellVersion = $LibraryIndex.GetLibVersionLatestName($gShellMain)

    #return $gShellMain, $gShellNewVersion
}