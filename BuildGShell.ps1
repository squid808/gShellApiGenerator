#First check for updated versions of the dependencies

#Foreach gshell dependency, check existing version of most recent build and compare to what is available from nuget

#Use main version of Google.Apis.Auth, since GShell depends on that and all dependencies, right?

function Get-GShellPackages {
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

function Get-GShellBuildFiles {
    $FilesList = Get-ChildItem "C:\Users\svarney\Desktop\GenOutput\gShell" -Recurse -Filter "*.cs"| select -ExpandProperty fullname `
        | where {$_ -notlike "*\obj\*"}

    $Files = New-Object system.collections.arraylist

    foreach ($File in $FilesList) {
        Add-String $Files ("    <Compile Include = `"" + $File.Replace("C:\Users\svarney\Desktop\GenOutput\gShell\","") + "`" />")
    }

    $FilesText = $Files -join "`r`n"

    return $FilesText
}

function Get-GShellProjReferences ($RootProjPath) {
    
    $Dependencies = New-Object system.collections.arraylist

    $latestGoogleAuthVersion = $LibraryIndex.GetLibVersionLatestName("Google.Apis.Auth")

    $DebugPath = ([System.IO.Path]::Combine($RootOutPath,"bin\Debug"))

    foreach ($D in $LibraryIndex.GetLibVersionDependencyChain("Google.Apis.Auth",$latestGoogleAuthVersion).GetEnumerator()) {
        if ($D.Name -ne "System.Net.Http") {
            $Version = [System.Reflection.Assembly]::LoadFrom($LibraryIndex.GetLibVersion($D.Name, $D.Value).dllPath).GetName().Version.ToString()
            
            $HintPath1 = Write-CSPReferenceHintPath -Name $D.Name -Version $D.Value -IsConditional $true
            $HintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\{1}\{0}.dll" -f $D.Name, $D.Value) -IsConditional $true
            $ReferenceText = Write-CSPReference $D.Name $Version $HintPath1 $HintPath2

            #$FullRefPath = [System.IO.Path]::Combine($RootProjPath, $HintPath)
            #$FullRefFolder = [System.IO.Path]::GetDirectoryName($FullRefPath)
            #
            #
            #if (-not (test-path $FullRefPath)) {
            #    
            #    #if (-not (test-path ))
            #
            #}            

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

    $SysAutoName = "System.Management.Automation"
    $SysAutoVersion = "10.0.10586.0"
    $AutomationHintPath1 = Write-CSPReferenceHintPath -Name $SysAutoName -Version $SysAutoVersion -IsConditional $true
    $AutomationHintPath2 = Write-CSPReferenceHintPath -HintPath ("..\..\Libraries\{0}\{1}\{0}.dll" -f $SysAutoName, $SysAutoVersion) -IsConditional $true
    Add-String $Dependencies (Write-CSPReference $SysAutoName "3.0.0.0" -HintPath1 $AutomationHintPath1 -HintPath2 $AutomationHintPath2 -Private $true)
    
    $DependenciesText = $Dependencies -join "`r`n"

    return $DependenciesText
}

function BuildGshell ($RootProjPath) {

    $packagesText = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
{0}
</packages>
'@ -f (Get-GShellPackages)

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
'@ -f (Get-GShellBuildFiles), (Get-GShellProjReferences $RootProjPath)

    $projText | Out-File -FilePath ([System.IO.Path]::Combine($RootProjPath, "gShell.csproj")) -Encoding utf8 -Force

    #Invoke-MsBuild -Path "C:\Users\svarney\Desktop\GenOutput\gShell\gShell.csproj"

}

buildgshell "C:\Users\svarney\Desktop\GenOutput\gShell"