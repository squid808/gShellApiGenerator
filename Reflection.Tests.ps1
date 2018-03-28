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
                            [pscustomobject]@{Value = "Something"}
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

    #Scopes
    $ExportedTypes.Add([pscustomobject]@{
        Name = "Scope"
        DeclaredFields = @(
            [pscustomobject]@{
                PSTypeName = 'System.Reflection.FieldInfo'
                Name = "Scope1Name"
                Uri = "Scope1Uri"
            },
            [pscustomobject]@{
                PSTypeName = 'System.Reflection.FieldInfo'
                Name = "Scope2Name"
                Uri = "Scope2Uri"
            }
        )
    }) | Out-Null

    #Resources / Service Objects
    $ExportedTypes.Add([pscustomobject]@{
        Name = "SomethingService"
        BaseType = [pscustomobject]@{
            FullName="Google.Apis.Services.BaseClientService"
        }
        DeclaredProperties = (Get-TestResources)
    }) | Out-Null

    $TestAssembly = [pscustomobject]@{
        PSTypeName = 'System.Reflection.Assembly'
        ImageRuntimeVersion = "v 1.2.3"
        FullName = "Google.Apis.Something.v1, Version=1.23.4.5678, Culture=neutral, PublicKeyToken=4b01fa6e34db77ab"
        ExportedTypes = $ExportedTypes
    }

    return $TestAssembly
}

function Get-TestResources {
    $Resources = @(
        [pscustomobject]@{ #This is a resource
            PSTypeName = 'System.Reflection.PropertyInfo'
            Name = "First"
            GetMethod = [pscustomobject]@{
                PSTypeName = 'System.Reflection.PropertyInfo'
                ReturnType = "Google.Apis.Something.v1.FirstResource"
            }
            PropertyType = [PSCustomObject]@{
                PSTypeName = "System.Reflection.TypeInfo"
                Name = "FirstResource"
                FullName = "Google.Apis.Something.v1.FirstResource"
                Namespace = "Google.Apis.Something.v1"
                DeclaredProperties =  @(
                    [pscustomobject]@{ #This is a child resource
                        PSTypeName = 'System.Reflection.PropertyInfo'
                        Name = "Sub"
                        GetMethod = [pscustomobject]@{
                            PSTypeName = 'System.Reflection.PropertyInfo'
                            ReturnType = "Google.Apis.Something.v1.FirstResource.SubResource"
                        }
                        PropertyType = [PSCustomObject]@{
                            PSTypeName = "System.Reflection.TypeInfo"
                            Name = "SubResource"
                            FullName = "Google.Apis.Something.v1.FirstResource+SubResource"
                            Namespace = "Google.Apis.Something.v1"
                        }
                    }
                )
            }
        },
        [pscustomobject]@{ #This is a resource
            PSTypeName = 'System.Reflection.PropertyInfo'
            Name = "Second"
            GetMethod = [pscustomobject]@{
                PSTypeName = 'System.Reflection.PropertyInfo'
                ReturnType = "Google.Apis.Something.v1.SecondResource"
            }
            PropertyType = [PSCustomObject]@{
                PSTypeName = "System.Reflection.TypeInfo"
                Name = "SecondResource"
                FullName = "Google.Apis.Something.v1.SecondResource"
                Namespace = "Google.Apis.Something.v1"
                DeclaredProperties =  @()
            }
        }
    ) 
    
    return $Resources
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
        auth = [pscustomobject]@{
            oauth2 = [pscustomobject]@{
                scopes = [pscustomobject]@{
                    Scope1Uri = [pscustomobject]@{Description="Scope1Description"}
                    Scope2Uri = [pscustomobject]@{Description="Scope2Description"}
                }
            }
        }
        resources = [pscustomobject]@{
            FirstResource = [pscustomobject]@{
                resources = [pscustomobject]@{
                    SubResource = [pscustomobject]@{}
                }
            }
            SecondResource = [pscustomobject]@{

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

    it "handles null or empty inputs" {
        {Get-ApiStandardQueryParams -Assembly $Null -RestJson $MockRestJson -Api $MockApi} | Should throw
        {Get-ApiStandardQueryParams -Assembly $MockAssembly -RestJson $Null -Api $MockApi} | Should throw
        {Get-ApiStandardQueryParams -Assembly $MockAssembly -RestJson "" -Api $MockApi} | Should throw
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
        #$DiscoveryName is valid if the Description comes up appropriately
        $Results[0].Description | should BeExactly "RestJsonDescription"
    }
}

Describe Get-ApiGShellBaseTypes {

    it "handles null or empty inputs" {
        {Get-ApiGShellBaseTypes $null $false} | Should Throw
        {Get-ApiGShellBaseTypes "" $false} | Should Throw
        {Get-ApiGShellBaseTypes "something" $null} | Should Throw
    }

    it "handles incorrect input" {
        {Get-ApiGShellBaseTypes "Not.A.Google.Namespace" $false} | Should Throw
    }

    it "handles Discovery API" {
        $Result = Get-ApiGShellBaseTypes "Google.Apis.Discovery.v1" $true
        $Result.CmdletBaseType | Should BeExactly "StandardQueryParametersBase"
        $Result.StandardQueryParamsBaseType | Should BeExactly "OAuth2CmdletBase"
        $Result.CanUseServiceAccount | Should Be $false
    }

    it "handles Admin APIs with Standard Query Params" {
        $Result = Get-ApiGShellBaseTypes "Google.Apis.Admin.Something.v1" $true
        $Result.CmdletBaseType | Should BeExactly "StandardQueryParametersBase"
        $Result.StandardQueryParamsBaseType | Should BeExactly "AuthenticatedCmdletBase"
        $Result.CanUseServiceAccount | Should Be $false
    }

    it "handles Admin APIs without Standard Query Params" {
        $Result = Get-ApiGShellBaseTypes "Google.Apis.Admin.Something.v1" $false
        $Result.CmdletBaseType | Should BeExactly "AuthenticatedCmdletBase"
        $Result.StandardQueryParamsBaseType | Should BeNullOrEmpty
        $Result.CanUseServiceAccount | Should Be $false
    }

    it "handles other APIs with Standard Query Params" {
        $Result = Get-ApiGShellBaseTypes "Google.Apis.Something.v1" $true
        $Result.CmdletBaseType | Should BeExactly "StandardQueryParametersBase"
        $Result.StandardQueryParamsBaseType | Should BeExactly "ServiceAccountCmdletBase"
        $Result.CanUseServiceAccount | Should Be $true
    }

    it "handles other APIs without Standard Query Params" {
        $Result = Get-ApiGShellBaseTypes "Google.Apis.Something.v1" $false
        $Result.CmdletBaseType | Should BeExactly "ServiceAccountCmdletBase"
        $Result.StandardQueryParamsBaseType | Should BeNullOrEmpty
        $Result.CanUseServiceAccount | Should Be $true
    }
}

Describe Get-ApiScopes {
    BeforeAll {
        $MockAssembly = Get-TestAssemblyObject
        $MockNoScopes = Get-TestAssemblyObject
        $MockRestJson = Get-TestRestJson
        $ScopeToRemove = $MockNoScopes.ExportedTypes | where Name -eq Scope
        $MockNoScopes.ExportedTypes.Remove($ScopeToRemove)
    }

    Mock Get-DeclaredFieldValue { return "Scope1Uri" } `
        -ParameterFilter { $DeclaredField.Name -eq "Scope1Name" }

    Mock Get-DeclaredFieldValue { return "Scope2Uri" } `
        -ParameterFilter { $DeclaredField.Name -eq "Scope2Name" }

    it "handles null or empty inputs" {
        {Get-ApiScopes $null $MockRestJson} | Should Throw
        {Get-ApiScopes $MockAssembly $Null} | Should Throw
        {Get-ApiScopes $MockAssembly ""} | Should Throw
    }

    it "handles assembly with no scope results" {
        {Get-ApiScopes $MockNoScopes $MockRestJson} | Should Throw
    }

    it "handles scope results" {
        $Results = Get-ApiScopes $MockAssembly $MockRestJson
        $Results.Count | Should Be 2
        $Results[0].Name | Should BeExactly "Scope1Name"
        $Results[0].Uri | Should BeExactly "Scope1Uri"
        $Results[0].Description | Should BeExactly "Scope1Description"
        $Results[1].Name | Should BeExactly "Scope2Name"
        $Results[1].Uri | Should BeExactly "Scope2Uri"
        $Results[1].Description | Should BeExactly "Scope2Description"
    }
}

Describe Get-DeclaredFieldValue {
    
    it "should handle null" {
        {Get-DeclaredFieldValue $null} | Should Throw
    }

    #pull in from powershell assembly since it should be present
    it "handles real value" {
        $Assembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation")
        $FieldInfo = $Assembly.ExportedTypes `
            | Select-Object -ExpandProperty DeclaredFields `
            | Where-Object {$_ -is [System.Reflection.FieldInfo]} `
            | Where-Object name -eq "converter" `
            | Select-Object -First 1
        $Result = Get-DeclaredFieldValue $FieldInfo

        "PSCredential" | Should BeIn $Result.Keys.Name

    }
}

Describe Get-Resources {
    $MockAssembly = Get-TestAssemblyObject
    $MockApi = New-Object Api

    mock New-ApiResource {return [PSCustomObject]@{}}

    it "handles null or wrong input" {
        {Get-Resources $null $MockApi} | Should Throw
        {Get-Resources "Foo" $MockApi} | Should Throw
        {Get-Resources $MockAssembly $null} | Should Throw
        {Get-Resources $MockAssembly "Foo"} | Should Throw
    }

    it "handles input" {
        $Results = Get-Resources -Assembly $MockAssembly -Api $MockApi
        $Results.Count | Should Be 1
    }
}

Describe New-ApiResource {
    BeforeAll {
        $MockResources = Get-TestResources
        $MockRestJson = Get-TestRestJson
        $MockApi = New-Object Api
    }

    it "handles null or incorrectly typed input" {
        {New-ApiResource -Resource $null -Api $Api -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource "" -Api $Api -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api $Null -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api "" -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api $Api -RestJson ""} | Should Throw
    }

    

}