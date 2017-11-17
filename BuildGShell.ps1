#TODO: Add -Force switch?

#First check for updated versions of the dependencies

#Foreach gshell dependency, check existing version of most recent build and compare to what is available from nuget

#Use main version of Google.Apis.Auth, since GShell depends on that and all dependencies, right?

function Get-GShellPackagesXml ($LibraryIndex) {
    $Packages = New-Object system.collections.arraylist

    $latestGoogleAuthVersion = $LibraryIndex.GetLibVersionLatestName("Google.Apis.Auth")
    $packageFormatString = '  <package id="{0}" version="{1}" targetFramework="net451" />'

    foreach ($D in $LibraryIndex.GetLibVersionDependencyChain("Google.Apis.Auth",$latestGoogleAuthVersion).GetEnumerator()) {
        if ($D.Name -ne "System.Net.Http") {
            Add-String $Packages ($packageFormatString -f $D.Name, $D.Value)
        }
    }

    Add-String $Packages ($packageFormatString -f "Google.Apis.Discovery.v1", $LibraryIndex.GetLibVersionLatestName("Google.Apis.Discovery.v1"))
    Add-String $Packages ($packageFormatString -f "Google.Apis.Oauth2.v2", $LibraryIndex.GetLibVersionLatestName("Google.Apis.Oauth2.v2"))
    Add-String $Packages ($packageFormatString -f "System.Management.Automation.dll", "10.0.10586.0")

    $PackagesText = $Packages -join "`r`n"

    return $PackagesText
}

function Get-GShellBuildFiles ($RootProjPath) {
    $FilesList = Get-ChildItem $RootProjPath -Recurse -Filter "*.cs"| select -ExpandProperty fullname `
        | where {$_ -notlike "*\obj\*"}

    $Files = New-Object system.collections.arraylist

    foreach ($File in $FilesList) {
        Add-String $Files ("    <Compile Include = `"" + $File.Replace(($RootProjPath+"\"),"") + "`" />")
    }

    $FilesText = $Files -join "`r`n"

    return $FilesText
}

function Get-GShellProjReferences ($RootProjPath, $LibraryIndex) {
    
    $Dependencies = New-Object system.collections.arraylist

    $latestGoogleAuthVersion = $LibraryIndex.GetLibVersionLatestName("Google.Apis.Auth")

    $DebugPath = ([System.IO.Path]::Combine($RootOutPath,"bin\Debug"))

    foreach ($D in $LibraryIndex.GetLibVersionDependencyChain("Google.Apis.Auth",$latestGoogleAuthVersion).GetEnumerator()) {
        if ($D.Name -ne "System.Net.Http") {
            $Version = [System.Reflection.Assembly]::LoadFrom($LibraryIndex.GetLibVersion($D.Name, $D.Value).dllPath).GetName().Version.ToString()
            
            $HintPath1 = Write-CSPReferenceHintPath -Name $D.Name -Version $D.Value -IsConditional $true
            $HintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\{1}\{0}.dll" -f $D.Name, $D.Value) -IsConditional $true
            $ReferenceText = Write-CSPReference $D.Name $Version $HintPath1 $HintPath2       

            Add-String $Dependencies $ReferenceText
        }
    }

    foreach ($Library in @("Google.Apis.Discovery.v1", "Google.Apis.Oauth2.v2")) {
        $Version = $LibraryIndex.GetLibVersionLatestName($Library)
        $HintPath1 = Write-CSPReferenceHintPath -Name $Library -Version $Version -IsConditional $true
        $HintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\{1}\{0}.dll" -f $Library, $Version) -IsConditional $true
        $AssemblyVersion = [System.Reflection.Assembly]::LoadFrom($LibraryIndex.GetLibVersion($Library, $Version).dllPath).GetName().Version.ToString()
        Add-String $Dependencies (Write-CSPReference $Library $AssemblyVersion -HintPath1 $HintPath1 -HintPath2 $HintPath2)
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

function BuildGshell ($RootProjPath, $LibraryIndex, [bool]$Log = $false) {

    $packagesText = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
{0}
</packages>
'@ -f (Get-GShellPackagesXml $LibraryIndex)

    $packagesText | Out-File -FilePath ([System.IO.Path]::Combine($RootProjPath, "packages.config")) -Encoding utf8 -Force

    $projText = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <MinimumVisualStudioVersion>10.0</MinimumVisualStudioVersion>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProjectGuid>{{150FF6C8-7AC1-41A1-AEF4-69151D7D3D19}}</ProjectGuid>
    <OutputType>Library</OutputType>
    <AppDesignerFolder>Properties</AppDesignerFolder>
    <RootNamespace>gShell.Main</RootNamespace>
    <AssemblyName>gShell</AssemblyName>
    <TargetFrameworkVersion>v4.5.1</TargetFrameworkVersion>
    <FileAlignment>512</FileAlignment>
    <TargetFrameworkProfile />
    <NuGetPackageImportStamp>1780389c</NuGetPackageImportStamp>
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
{0}
  </ItemGroup>
  <ItemGroup>
    <Reference Include="System" />
    <Reference Include="System.Security" />
{1}
  </ItemGroup>
  <ItemGroup>
    <None Include="app.config" />
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
'@ -f (Get-GShellBuildFiles $RootProjPath), (Get-GShellProjReferences $RootProjPath $LibraryIndex)

    $projFilePath = [System.IO.Path]::Combine($RootProjPath, "gShell.csproj")

    $projText | Out-File -FilePath $projFilePath -Encoding utf8 -Force

    #TODO: Update the assembly info to update the year and the file version!
    Log ("Building gShell.Main") $Log

    $BuildResult = Invoke-MsBuild -Path $projFilePath

    if ($BuildResult.BuildSucceeded -eq $true) {
        Log ("Building succeeded") $Log
        #return the path to the resulting dll file
        $gShellPath = [System.IO.Path]::Combine($RootProjPath,"bin\Debug\gShell.dll")
        return $gShellPath
    } else {
        Log ("Build failed") $Log
        #todo: throw error and stop process here?
    }
}

function SaveGshellToLibraryIndex ($Version, $Location, $LibraryIndex, $Dependencies, [bool]$Log = $false) {
    $gShellMain = "gShell.Main"
    if (-not $LibraryIndex.HasLib($gShellMain)) {
        Log ("gShell.Main doesn't exist in the Library Index - adding entry") $Log
        $LibraryIndex.AddLib($gShellMain)
    }

    if (-not $LibraryIndex.HasLibVersion($gShellMain, $Version)) {
        Log ("gShell.Main doesn't have an entry for version $Version - adding with dependencies") $Log
        $LibraryIndex.AddLibVersion($gShellMain, $Version)

        #this is more for the other APIs to be able to know what versions of the files THEY need are referenced,
        # so it can lack the oauth and the discovery references
        foreach ($Dependency in $Dependencies.GetEnumerator()) {
            $LibraryIndex.AddLibVersionDependency($gShellMain, $Version, $Dependency.Name, $Dependency.Value)
        }

        
    }

    $LibraryIndex.GetLibVersion($gShellMain, $Version)."dllPath" = $Location
    $LibraryIndex.SetLibLastVersionBuilt($gShellMain, $Version)

    $LibraryIndex.Save()
}

function CheckAndBuildGshell ($RootProjPath, $LibraryIndex, [bool]$Log = $false, [bool]$Force = $false) {

    $Dependencies = @{}

    foreach ($D in $LibraryIndex.GetLibVersionDependencyChain("Google.Apis.Auth",$latestGoogleAuthVersion).GetEnumerator()) {
        if ($D.Name -ne "System.Net.Http") {
            $Dependencies[$D.Name] = $D.Value
        }
    }

    $Dependencies["System.Management.Automation.dll"] = "10.0.10586"

    #We're tying gShell to the version of the Auth package since it and its dependencies all appear to match. If they change this we may need to reevaluate
    $AuthVersion = $Dependencies["Google.Apis.Auth"]
    $AuthVersionObj = [System.Version]$AuthVersion

    $gShellMain = "gShell.Main"
    $gShellVersion = $LibraryIndex.GetLibVersionLatestName($gShellMain)
    $gShellVersionObj = [System.Version]$gShellVersion

    if (-not $LibraryIndex.HasLib("gShell.Main") -or ($gShellVersionObj -lt $AuthVersionObj) -or $Force) {

        Log ("$gShellMain $gShellVersion either doesn't exist or needs to be updated to $AuthVersion.") $Log
        $gShellNewVersion = $AuthVersion + ".0"

        #First, try to build
        $CompiledPath = BuildGshell $RootProjPath $LibraryIndex

        if ($CompiledPath -ne $null) {
            Log ("Copying the compiled $gShellMain.dll file to the Library Index path") $Log
            #copy the file to the library path
            $LibraryRootPath = [System.IO.Path]::GetDirectoryName($LibraryIndex.RootPath)
            $NewGShellFolderPath = [System.IO.Path]::Combine($LibraryRootPath, $gShellMain, $gShellNewVersion)
            $NewGShellPath = [System.IO.Path]::Combine($NewGShellFolderPath, "gShell.dll")
            if (-not (Test-Path $NewGShellFolderPath)) {
                New-Item -Path $NewGShellFolderPath -ItemType "Directory" | Out-Null
            }
            Copy-Item -Path $CompiledPath -Destination $NewGShellPath | Out-Null

            #update the library
            $LibraryIndex.SetLibLastVersionBuilt("Google.Apis.Auth", $AuthVersion)
            SaveGshellToLibraryIndex -Version $gShellNewVersion -Location $NewGShellPath -LibraryIndex $LibraryIndex -Dependencies $Dependencies
            
        } else {
            #throw some error right?
        }

        $gShellVersion = $LibraryIndex.GetLibVersionLatestName($gShellMain)
    } else {
        Log ("$gShellMain $gShellVersion appears to be up to date") $Log
    }

    return $gShellMain, $gShellNewVersion
}