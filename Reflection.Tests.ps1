. ($MyInvocation.MyCommand.Path -replace "Tests.","")

#region General Functions
Describe Test-ObjectType {
    it "handles simple objects" {
        (42 | Test-ObjectType "System.Int32") | should be $true
        (42 | Test-ObjectType "int") | should be $true
        (42 | Test-ObjectType "System.String") | should be $false
        ("hi" | Test-ObjectType "System.String") | should be $true
    }

    it "handles simple multimatch" {
        (42 | Test-ObjectType "System.Int32","int" -MatchAll) | should be $true
        (42 | Test-ObjectType "System.Int32","int","string" -MatchAll) | should be $false
    }

    it "handles interfaces" {
        ,(New-Object System.Collections.ArrayList) | Test-ObjectType "System.Collections.IEnumerable" | should be $true

        Test-ObjectType -Object (New-Object System.Collections.ArrayList) `
            "System.Collections.ArrayList","System.Collections.IEnumerable" -MatchAll | should be $true
    }

    it "handles complex or mocked objects" {
        $MyTestObj = [pscustomobject]@{
            PSTypeName = 'System.Reflection.Assembly'
            ImageRuntimeVersion = "v 1.2.3"
        }

        $MyTestObj | Test-ObjectType "PSCustomObject","System.Reflection.Assembly" | should be $true
        $MyTestObj | Test-ObjectType "PSCustomObject","System.Reflection.Assembly" -MatchAll | should be $true
    }
}

Describe Clean-CommentString {
    It "handles null" {
        Clean-CommentString $null | Should be $null
    }

    It "handles empty" {
        Clean-CommentString "" | Should be ""
    }

    It "removes double quotes" {
        Clean-CommentString '""' | Should be "''"
    }
}

Describe ConvertTo-FirstLower {
    It "handles null" {
        ConvertTo-FirstLower $null | Should be $null
    }

    It "handles empty" {
        ConvertTo-FirstLower "" | Should be ""
    }

    It "handles non-character" {
        ConvertTo-FirstLower "1" | should be "1"
        ConvertTo-FirstLower "-" | should be "-"
    }

    It "makes single letter lower" {
        ConvertTo-FirstLower "A" | Should be "a"
    }

    it "makes only first letter lower" {
        ConvertTo-FirstLower "ABCD" | Should be "ABCD"
    }

    it "handles already lower" {
        ConvertTo-FirstLower "a" | should be "a"
    }
}

Describe ConvertTo-FirstUpper {
    It "handles null" {
        ConvertTo-FirstUpper $null | Should be $null
    }

    It "handles empty" {
        ConvertTo-FirstUpper "" | Should be ""
    }

    It "handles non-character" {
        ConvertTo-FirstUpper "1" | should be "1"
        ConvertTo-FirstUpper "-" | should be "-"
    }

    It "makes single letter lower" {
        ConvertTo-FirstUpper "a" | Should be "A"
    }

    it "makes only first letter lower" {
        ConvertTo-FirstUpper "abcd" | Should be "Abcd"
    }

    it "handles already upper" {
        ConvertTo-FirstLower "A" | should be "A"
    }
}

Describe Has-ObjProperty {
    $TestObj = New-Object -TypeName psobject -Property @{"foo"="bar"}

    it "finds objects that exists" {
        $TestObj | Has-ObjProperty -Target "foo" | should be $true
    }

    it "doesn't find missing object" {
        $TestObj | Has-ObjProperty -Target "fizz" | should be $false
    }

    it "throws error on missing object" {
        {Has-ObjProperty $null "foo" -ErrorAction Stop} | should Throw
    }
}
#endregion

#Create and return a known, false Assembly object for use in unit tests
function Get-TestAssemblyObject {
    $ExportedTypes = New-Object System.Collections.ArrayList

    $ExportedTypes.Add([pscustomobject]@{
        Name = "SomethingBaseServiceRequest?1"
        BaseType = [pscustomobject]@{Name="ClientServiceRequest``1"}
        DeclaredProperties = @(
            [pscustomobject]@{
                Name = "Foo"
                CustomAttributes = @(
                    [pscustomobject]@{
                        AttributeType = "SomethingRequestParameterAttribute"
                        ConstructorArguments = @(
                            [pscustomobject]@{Value = "ConstructorName1"}
                            [pscustomobject]@{Value = "ConstructorName2"}
                        )
                    }
                    [pscustomobject]@{AttributeType = "SomethingElse"}
                )
            }
            [pscustomobject]@{Name = "Alt"}
        )
    }) | Out-Null

    #Wrong Name
    $ExportedTypes.Add([pscustomobject]@{
        Name = "SomethingOtherServiceRequest?1"
        BaseType = [pscustomobject]@{Name="ClientServiceRequest``1"}
        DeclaredProperties = @([pscustomobject]@{Name = "Bar"})
    }) | Out-Null
    
    #Wrong BaseTypeName
    $ExportedTypes.Add([pscustomobject]@{
        Name = "SomethingBaseServiceRequest?1"
        BaseType = [pscustomobject]@{Name="NotClientServiceRequest``1"}
        DeclaredProperties = @([pscustomobject]@{Name = "Bar"})
    }) | Out-Null

    $TestAssembly = [pscustomobject]@{
        PSTypeName = 'System.Reflection.Assembly'
        ImageRuntimeVersion = "v 1.2.3"
        FullName = "Google.Apis.Something.v1, Version=1.23.4.5678, Culture=neutral, PublicKeyToken=4b01fa6e34db77ab"
        ExportedTypes = $ExportedTypes
    }

    return $TestAssembly
}

#Create and return a known, false Json object for use in unit tests
function Get-TestRestJson {
    #TODO: Start here
    $TestJson = [pscustomobject]@{
        parameters = [pscustomobject]@{
            Something = [pscustomobject]@{
                Description = "RestJsonDescription"
            }
        }
    }
    return $TestJson
}

Describe New-Api {

    BeforeAll {
        $MockResource = New-Object ApiResource -Property @{Name="MockResource"}
        $MockAssembly = Get-TestAssemblyObject
        $MockRestJson = Get-TestRestJson
    }

    mock Get-ApiStandardQueryParams { return ,@("MockSQPs") }
    mock Get-Resources { return ,@($MockResource) }
    mock Get-ApiScopes { return ,@("MockScopes") }
    mock Get-ApiGShellBaseTypes { return [PSCustomObject]@{
        CmdletBaseType = "MockCBT"
        StandardQueryParamsBaseType = "MockSQPBT"
        CanUseServiceAccount = $true
    }}

    it "handles null input" {
        {New-Api -Assembly $null -RestJson $MockRestJson} | Should Throw
        {New-Api -Assembly $MockAssembly -RestJson $Null} | Should Throw
    }

    it "handles wrong assembly input" {
        {New-Api -Assembly "foo" -RestJson $MockRestJson} | Should Throw
    }
    
    context "standard naming" {
        $Api = New-Api -Assembly $MockAssembly -RestJson $MockRestJson

        it "calls sub methods" {
            Assert-MockCalled Get-ApiStandardQueryParams -Times 1
            Assert-MockCalled Get-Resources -Times 1
            Assert-MockCalled Get-ApiScopes -Times 1
            Assert-MockCalled Get-ApiGShellBaseTypes -Times 1
        }

        it "has expected information" {
            $Api.Name | Should -BeExactly "Something"
            $Api.NameLower | Should -BeExactly "something"
            $Api.NameAndVersion | Should -BeExactly "Something.v1"
            $Api.NameAndVersionLower | Should -BeExactly "something.v1"
            $MockResource | Should -BeIn $Api.Resources
            "MockResource" | Should -BeIn $Api.ResourcesDict.Keys
            $Api.RootNamespace | Should -BeExactly "Google.Apis.Something.v1"
            $Api.DataNamespace | Should -BeExactly "Google.Apis.Something.v1.Data"
            $Api.Version | Should -BeExactly "v1"
            $Api.AssemblyVersion | Should -BeExactly "1.23.4.5678"
            $Api.ApiName | Should -BeNullOrEmpty
            $Api.DiscoveryObj | Should -BeExactly $MockRestJson
            $Api.HasStandardQueryParams | Should -Be $true
            "MockSQPs" | Should -BeIn $Api.StandardQueryparams
            $Api.StandardQueryParamsBaseType | Should -BeExactly "MockSQPBT"
            $Api.CanUseServiceAccount | Should -Be $true
            $Api.SchemaObjects.Count | Should -BeExactly 0
            $Api.SchemaObjectsDict.Keys.Count | Should -BeExactly 0
            $Api.CmdletBaseType | Should -BeExactly "MockCBT"
            "MockScopes" | Should -BeIn $Api.Scopes
        }
    }

    context "admin naming" {

        $MockAssembly.FullName = $MockAssembly.FullName -replace "Google.Apis.Something.v1","Google.Apis.Admin.Something.v1"

        $Api = New-Api -Assembly $MockAssembly -RestJson $MockRestJson

        it "has expected information" {
            $Api.Name | Should -BeExactly "Something"
            $Api.NameLower | Should -BeExactly "something"
            $Api.NameAndVersion | Should -BeExactly "Something.v1"
            $Api.NameAndVersionLower | Should -BeExactly "something.v1"
        }

    }
}

Describe Get-ApiStandardQueryParams {

    BeforeAll {
        $MockAssembly = Get-TestAssemblyObject
        $MockRestJson = Get-TestRestJson
        $MockApi = New-Object Api
    }

    mock Get-ApiPropertyType { return "MockType" }

    it "handles null inputs" {
        {Get-ApiStandardQueryParams -Assembly $Null -RestJson $MockRestJson -Api $MockApi} | Should throw
        {Get-ApiStandardQueryParams -Assembly $MockAssembly -RestJson $Null -Api $MockApi} | Should throw
        {Get-ApiStandardQueryParams -Assembly $MockAssembly -RestJson $MockRestJson -Api $Null} | Should throw
    }

    $Results = Get-ApiStandardQueryParams -Assembly $MockAssembly -RestJson $MockRestJson -Api $MockApi

    it "finds appropriate properties" {
        "Foo" | should bein $Results.Name
        "Alt" | should not bein $Results.Name
        "Bar" | should not bein $Results.Name
    }

    it "populates members correctly" {
        $Results[0].Api | should be $MockApi
        $Results[0].ReflectedObj | should BeExactly $MockAssembly.ExportedTypes[0].DeclaredProperties[0]
        $Results[0].Name | should BeExactly "Foo"
        $Results[0].NameLower | should BeExactly "foo"
        $Results[0].Type | should BeExactly "MockType"
        #TODO - how to test this since it's not part of the details? split it out to function?
        #$DiscoveryName | should BeExactly "ConstructorName1"
        #$Results[0].Description | should BeExactly "RestJsonDescription"
    }
}