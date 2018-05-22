. ($MyInvocation.MyCommand.Path -replace "Tests.","")
. ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path),"TemplatingMain.ps1"))
. ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path),"LibraryIndex.ps1"))
. ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path),"Nuget.ps1"))

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
                DeclaredMethods = (Get-TestMethods)
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

function Get-TestMethods {
    #looking for IsVirtual and -not IsFinal
    #Also where ReturnType.ImplementedInterfaces.Name -contains "IClientServiceRequest"
    $Methods = @(
        #Good Results
        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Get"
            IsVirtual = $true
            IsFinal = $false
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{
                    Name = @(
                        "IClientServiceRequest``1"
                        "IClientServiceRequest"
                    )
                }
                BaseType = "Google.Apis.Something.ClientServiceRequest`1[Google.Apis.Something.v1.Data.SomeOtherThingA]"
                DeclaredProperties = [PSCustomObject]@{
                    SetMethod = "NotNull"
                    Name = "NotAPageTokenOrStandardQueryParam"
                }
            }
        },

        #Good Result
        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Create"
            IsVirtual = $true
            IsFinal = $false
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{
                    Name = @(
                        "IClientServiceRequest``1"
                        "IClientServiceRequest"
                    )
                }
                BaseType = "Google.Apis.Something.ClientServiceRequest`1[Google.Apis.Something.v1.Data.SomeOtherThingA]"
            }
        },

        #UploadMethod
        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Create"
            IsVirtual = $true
            IsFinal = $false
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{}
                BaseType = "Google.Apis.Upload.ResumableUpload`1[Google.Apis.Something.v1.Data.SomeOtherThingB]"
            }
        },

        #Bad Methods
        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Foo"
            IsVirtual = $true
            IsFinal = $true
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{
                    Name = @(
                        "IClientServiceRequest``1"
                        "IClientServiceRequest"
                    )
                }
                BaseType = "Google.Apis.Something.ClientServiceRequest`1[Google.Apis.Something.v1.Data.SomeOtherThingA]"
            }
        },

        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Bar"
            IsVirtual = $false
            IsFinal = $false
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{
                    Name = @(
                        "IClientServiceRequest``1"
                        "IClientServiceRequest"
                    )
                }
                BaseType = "Google.Apis.Something.ClientServiceRequest`1[Google.Apis.Something.v1.Data.SomeOtherThingA]"
            }
        },

        [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            Name = "Fizz"
            IsVirtual = $true
            IsFinal = $false
            ReturnType = [PSCustomObject]@{
                ImplementedInterfaces = [PSCustomObject]@{
                    Name = @(
                        "nope"
                    )
                }
                BaseType = "Google.Apis.Something.ClientServiceRequest`1[Google.Apis.Something.v1.Data.SomeOtherThingA]"
            }
        }
    )

    return $Methods
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
            First = [pscustomobject]@{
                resources = [pscustomobject]@{
                    Sub = [pscustomobject]@{}
                }
            }
            Second = [pscustomobject]@{

            }
        }
        methods = [pscustomobject]@{
            get = [pscustomobject]@{description = "MethodGetDescription"}
            create = [pscustomobject]@{description = "MethodCreateDescription"}
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
    
    it "handles null or incorrect input" {
        {Get-DeclaredFieldValue $null} | Should Throw
        {Get-DeclaredFieldValue "Foo"} | Should Throw
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
    $MockApi.DiscoveryObj = "Json"

    mock New-ApiResource {return [PSCustomObject]@{}}

    it "handles null or wrong input" {
        {Get-Resources $null $MockApi} | Should Throw
        {Get-Resources "Foo" $MockApi} | Should Throw
        {Get-Resources $MockAssembly $null} | Should Throw
        {Get-Resources $MockAssembly "Foo"} | Should Throw
    }

    it "handles input" {
        $Results = Get-Resources -Assembly $MockAssembly -Api $MockApi
        $Results.Count | Should Be 2
    }
}

Describe New-ApiResource {
    BeforeAll {
        $MockResources = Get-TestResources
        $MockRestJson = Get-TestRestJson
        $MockApi = New-Object Api
    }

    mock Get-ApiResourceMethods {return ,@([PSCustomObject]@{Name="MockMethod"})}

    it "handles null or incorrectly typed input" {
        {New-ApiResource -Resource $null -Api $Api -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource "" -Api $Api -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api $Null -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api "" -RestJson $MockRestJson} | Should Throw
        {New-ApiResource -Resource $MockResources[0] -Api $Api -RestJson ""} | Should Throw
    }

    it "handles input" {
        $Result1 = New-ApiResource -Resource $MockResources[0] -Api $MockApi -RestJson $MockRestJson
        $Result1.Api | Should Be $MockApi
        $Result1.ReflectedObj | Should Be $MockResources[0].PropertyType
        $Result1.Name | Should BeExactly "First"
        $Result1.NameLower | Should BeExactly "first"
        $Result1.FullName | Should BeExactly "Google.Apis.Something.v1.FirstResource"
        $Result1.Namespace | Should BeExactly "Google.Apis.Something.v1"
        $Result1.ParentResource | Should BeNullOrEmpty
        $Result1.DiscoveryObj | Should Be $MockRestJson.resources.First
        $Result1.ChildResources.Count | Should Be 1
        "Sub" | Should BeIn $Result1.ChildResourcesDict.Keys
        $Result1.Methods.Count | Should Be 1
        "MockMethod" | Should BeIn $Result1.MethodsDict.Keys

        Assert-MockCalled Get-ApiResourceMethods -Exactly -Times 2

        $Result1.ChildResourcesDict["Sub"].ParentResource | Should Be $Result1
        $Result1.ChildResourcesDict["Sub"].FullName | Should Be "Google.Apis.Something.v1.FirstResource+SubResource"
        $Result1.ChildResourcesDict["Sub"].Namespace | Should Be "Google.Apis.Something.v1"

        $Result2 = New-ApiResource -Resource $MockResources[1] -Api $MockApi -RestJson $MockRestJson
        $Result2.ChildResources.Count | Should Be 0
    }

}

Describe Get-ApiResourceMethods {
    
    mock New-ApiMethod {
        $M = New-Object ApiMethod 
        $M.Name = $Method.Name
        return $M
    }

    $MockMethodProperty1 = New-Object ApiMethodProperty
    $MockMethodProperty1.Name = "StreamObj"
    $MockMethodProperty1.Type = [PSCustomObject]@{Type = "System.IO.Stream"}
    $MockMethodProperty1.Required = $true

    $MockMethodProperty2 = New-Object ApiMethodProperty
    $MockMethodProperty2.Name = "ContentType"
    $MockMethodProperty2.Type = [PSCustomObject]@{Type = "string"}
    $MockMethodProperty2.Required = $true

    $MockMethodProperty3 = New-Object ApiMethodProperty
    $MockMethodProperty3.Name = "ContentType"
    $MockMethodProperty3.Type = [PSCustomObject]@{Type = "Foo"}
    $MockMethodProperty3.Required = $true

    $MockMethodProperty4 = New-Object ApiMethodProperty
    $MockMethodProperty4.Name = "bar"
    $MockMethodProperty4.Type = [PSCustomObject]@{Type = "string"}
    $MockMethodProperty4.Required = $true

    mock New-ApiMethod { 
        $M = New-Object ApiMethod 
        $M.Name = $Method.Name
        $M.Parameters.AddRange(@(
            $MockMethodProperty1,
            $MockMethodProperty2,
            $MockMethodProperty3,
            $MockMethodProperty4
        ))
        return $M
    } -ParameterFilter {$UseReturnTypeGenericInt -eq 1}

    mock Get-MethodInfoParameters {return ,@(
        [PSCustomObject]@{
            ParameterType = [PSCustomObject]@{
                FullName = @("Foo","System.IO.Stream","Bar")
            }
        }
    )}

    $MockResources = Get-TestResources
    $MockApiResource = New-Object ApiResource

    it "handles null or incorrect input" {
        $TypeObject = [PSCustomObject]@{PSTypeName = 'System.Reflection.TypeInfo'}
        {Get-ApiResourceMethods $Null $TypeObject } | should Throw
        {Get-ApiResourceMethods "Foo" $TypeObject } | should Throw
        {Get-ApiResourceMethods $MockApiResource $Null } | should Throw
        {Get-ApiResourceMethods $MockApiResource "Bar" } | should Throw
    }

    $Results = Get-ApiResourceMethods -Resource $MockApiResource -ResourceType $MockResources[0].PropertyType

    it "gets proper method results" {
        $Results.Count | Should Be 2

        "Get" | Should BeIn $Results.Name
        "Create" | Should BeIn $Results.Name
        "Foo" | Should Not BeIn $Results.Name
        "Bar" | Should Not BeIn $Results.Name
        "Fizz" | Should Not BeIn $Results.Name
    }

    it "properly assigns upload methods" {

        $Get = $Results | Where-Object Name -eq "Get"
        $Get.SupportsMediaUpload | Should Be $false
        $Get.UploadMethod | Should BeNullOrEmpty

        $Create = $Results | Where-Object Name -eq "Create"
        $Create.SupportsMediaUpload | Should Be $false
        $Create.UploadMethod | Should Not BeNullOrEmpty
        $Create.UploadMethod.SupportsMediaUpload | Should Be $true
    }

    it "properly adjusts upload method parameters" {

        $Create = $Results | Where-Object Name -eq "Create"
        
        $Create.UploadMethod.Parameters.Count | Should Be 4

        $Create.UploadMethod.Parameters[0].Name | Should Be "StreamObj"
        $Create.UploadMethod.Parameters[0].ShouldIncludeInTemplates | Should Be $false
        $Create.UploadMethod.Parameters[0].Required | Should Be $false

        $Create.UploadMethod.Parameters[1].Name | Should Be "ContentType"
        $Create.UploadMethod.Parameters[1].Type.Type | Should Be "string"
        $Create.UploadMethod.Parameters[1].ShouldIncludeInTemplates | Should Be $false
        $Create.UploadMethod.Parameters[1].Required | Should Be $false

        $Create.UploadMethod.Parameters[2].Name | Should Be "ContentType"
        $Create.UploadMethod.Parameters[2].Type.Type | Should Be "foo"
        $Create.UploadMethod.Parameters[2].ShouldIncludeInTemplates | Should Be $true
        $Create.UploadMethod.Parameters[2].Required | Should Be $true

        $Create.UploadMethod.Parameters[3].Name | Should Be "bar"
        $Create.UploadMethod.Parameters[3].Type.Type | Should Be "string"
        $Create.UploadMethod.Parameters[3].ShouldIncludeInTemplates | Should Be $true
        $Create.UploadMethod.Parameters[3].Required | Should Be $true
    }
}

Describe Get-MethodInfoParameters {
    it "handles null or incorrect input" {
        {Get-MethodInfoParameters -Method $null}
    }

    it "handles real value" {
        $Assembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation")
        $MethodInfo = $Assembly.ExportedTypes `
            | Select-Object -ExpandProperty DeclaredMethods `
            | Where-Object {$_ -is [System.Reflection.MethodInfo]} `
            | Where-Object Name -eq "AddGenericArguments" `
            | Select-Object -First 1

        $Results = Get-MethodInfoParameters -Method $MethodInfo

        "genericArguments" | Should BeIn $Results.Name
        "dropNamespaces" | Should BeIn $Results.Name

    }
}

Describe Get-ApiMethodNoun {
    $MockApiMethod = New-Object ApiMethod
    $MockApiName = "Fizz"
    $MockApiVersion = "v1"

    #TODO - figure out how to mock this when it's not in a module
    mock Get-ParentResourceChain { return $null }

    it "handles null or incorrect input" {
        {Get-ApiMethodNoun -ApiMethod $null -ApiName $MockApiName -ApiVersion $MockApiVersion} | Should Throw
        {Get-ApiMethodNoun -ApiMethod "Foo" -ApiName $MockApiName -ApiVersion $MockApiVersion} | Should Throw
        {Get-ApiMethodNoun -ApiMethod $MockApiMethod -ApiName $null -ApiVersion $MockApiVersion} | Should Throw
        {Get-ApiMethodNoun -ApiMethod $MockApiMethod -ApiName 1 -ApiVersion $MockApiVersion} | Should Throw
        {Get-ApiMethodNoun -ApiMethod $MockApiMethod -ApiName $MockApiName -ApiVersion $null} | Should Throw
        {Get-ApiMethodNoun -ApiMethod $MockApiMethod -ApiName $MockApiName -ApiVersion 1} | Should Throw
    }

    it "gets appropriate result" {
        $Result = Get-ApiMethodNoun -ApiMethod $MockApiMethod -ApiName $MockApiName -ApiVersion 1

        $Result | Should BeExactly "GFizzV1"

    }
}

Describe New-ApiMethod {

    #region Setup
    $MockMethods = Get-TestMethods
    $MockApi = New-Object Api
    $MockRestJson = Get-TestRestJson
    $MockApiResource = New-Object ApiResource
    $MockApiResource.Api = $MockApi
    $MockApiResource.DiscoveryObj = $MockRestJson

    $MockMethodInfoParam = [PSCustomObject]@{Name = "FooMethodInfoParam"}

    #Passed to New-ApiMethodProperty to determine the return type
    mock Get-ApiMethodReturnType {return "FooReturnType"}
    $ApiMethodPropertyMockReturnReturn = [PSCustomObject]@{Name="ReturnTypeProperty";Type=$null}
    mock New-ApiMethodProperty {return $ApiMethodPropertyMockReturnReturn} -ParameterFilter {$Property -eq "FooReturnType"}

    #Works out the type of the return type - if it needs to be string or void
    mock Get-ApiMethodReturnTypeType {return "ReturnTypePropertyType"} -ParameterFilter {$MethodReturnTypeName -eq "ReturnTypeProperty"}
    
    #Used in getting properties of the virtual method
    $ApiMethodPropertyMockInfoReturn = [PSCustomObject]@{Name="FooMethodProperty1";Type=$null}
    mock Get-MethodInfoParameters { return $MockMethodInfoParam } -ParameterFilter {$Method -eq $MockMethods[0]}
    mock New-ApiMethodProperty {return $ApiMethodPropertyMockInfoReturn} -ParameterFilter {$Property -eq $MockMethodInfoParam}
    #endregion

    it "handles null or incorrect input" {
        {New-ApiMethod -Resource $null -Method $MockMethods[0]} | Should Throw
        {New-ApiMethod -Resource "Foo" -Method $MockMethods[0]} | Should Throw
        {New-ApiMethod -Resource $MockApiResource -Method $null} | Should Throw
        {New-ApiMethod -Resource $MockApiResource -Method "Bar"} | Should Throw
    }

    it "sets up the api method properly" {
        $Result = New-ApiMethod -Resource $MockApiResource -Method $MockMethods[0]

        $Result.Resource | Should Be $MockApiResource
        $Result.Api | Should Be $MockApi
        $Result.ParentResource | Should Be $MockApiResource
        $Result.ReflectedObj | Should Be $MockMethods[0]
        $Result.DiscoveryObj | Should Be $MockRestJson.methods.Get

        $Result.Name | Should Be "Get"
        $Result.Description | Should Be "MethodGetDescription"

        $Result.ReturnType.Name | Should Be "ReturnTypeProperty"
        $Result.ReturnType.Type | Should Be "ReturnTypePropertyType"

        #Properties from the virtual method
        $ApiMethodPropertyMockInfoReturn | Should BeIn $Result.Parameters
        $ApiMethodPropertyMockInfoReturn | Should BeIn $Result.VirtualParameters

        #Params from the request class
        $Result.Parameters | Where-Object {$_.Name -eq "NotAPageTokenOrStandardQueryParam"} | Should Be $true
        $Result.VirtualParameters | Where-Object {$_.Name -eq "NotAPageTokenOrStandardQueryParam"} | Should Be $true
    }
}

Describe Test-ApiMethodHasPagedResults {
    BeforeEach {
        $MockApiMethod = New-Object ApiMethod
        $MockApiMethod.ReturnType = [PSCustomObject]@{
            ReflectedObject = [PSCustomObject]@{
                DeclaredProperties = [PSCustomObject]@{
                    Name = @("Foo","NextPageToken","Bar")
                }
            }
        }
        
        $MockMethod = [PSCustomObject]@{
            PSTypeName = 'System.Reflection.MethodInfo'
            ReturnType = [PSCustomObject]@{
                DeclaredProperties = [PSCustomObject]@{
                    Name = @("Fizz","PageToken","Buzz")
                }
            }
        }
    }
    
    It "handles null or incorrect input" {
        {Test-ApiMethodHasPagedResults -ApiMethod $null -Method $MockMethod} | Should Throw
        {Test-ApiMethodHasPagedResults -ApiMethod "" -Method $MockMethod} | Should Throw
        {Test-ApiMethodHasPagedResults -ApiMethod $MockApiMethod -Method $null} | Should Throw
        {Test-ApiMethodHasPagedResults -ApiMethod $MockApiMethod -Method ""} | Should Throw
    }

    It "finds paged results" {
        Test-ApiMethodHasPagedResults -ApiMethod $MockApiMethod -Method $MockMethod | Should Be $true
    }

    It "finds no NextPageToken in ApiMethod" {
        $MockApiMethod.ReturnType.ReflectedObject.DeclaredProperties.Name = @("Foo","Bar")

        Test-ApiMethodHasPagedResults -ApiMethod $MockApiMethod -Method $MockMethod | Should Be $false
    }

    It "finds no PageToken in Method" {
        $MockMethod.ReturnType.DeclaredProperties.Name = @("Fizz","Buzz")
        
        Test-ApiMethodHasPagedResults -ApiMethod $MockApiMethod -Method $MockMethod | Should Be $false
    }
}

Describe Get-ApiMethodReturnTypeType {
    Mock New-BasicTypeStruct {return "StringResult"} -ParameterFilter {$Type -like "string"}
    Mock New-BasicTypeStruct {return "VoidResult"}

    it "handles null or incorrect input" {
        {Get-ApiMethodReturnTypeType -MethodReturnTypeName $null} | Should Throw
        {Get-ApiMethodReturnTypeType -MethodReturnTypeName ""} | Should Throw
        {Get-ApiMethodReturnTypeType -MethodReturnTypeName [PSCustomObject]@{}} | Should Throw
    }

    it "provides expected response" {
        Get-ApiMethodReturnTypeType -MethodReturnTypeName "String" | Should Be "StringResult"
        Get-ApiMethodReturnTypeType -MethodReturnTypeName "string" | Should Be "StringResult"
        Get-ApiMethodReturnTypeType -MethodReturnTypeName "Foo" | Should Be "VoidResult"
    }
}

Describe Get-ApiPropertyTypeShortName {

    it "handles null or incorrect input" {
        {Get-ApiPropertyTypeShortName -Name $null -ApiRootNameSpace "NotNull"} | Should Throw
        {Get-ApiPropertyTypeShortName -Name [pscustomobject]@{} -ApiRootNameSpace "NotNull"} | Should Throw
        {Get-ApiPropertyTypeShortName -Name "NotNull" -ApiRootNameSpace $null} | Should Throw
        {Get-ApiPropertyTypeShortName -Name "NotNull"@{} -ApiRootNameSpace [pscustomobject]@{}} | Should Throw

    }

    it "handles system types" {

        $TypeResults = @{
            "System.String" = "string" 
            "String" = "string"
            "System.Int32" = "int"
            "Int32" = "int"
            "System.Boolean" = "bool"
            "Boolean" = "bool"
            "System.Int64" = "long"
            "Int64" = "long"
        }

        foreach ($Key in $TypeResults.Keys) {
            Get-ApiPropertyTypeShortName -Name $Key -ApiRootNameSpace "anything" | Should BeExactly $TypeResults[$Key]
        }
    }

    it "handles root namespaces" {
        Get-ApiPropertyTypeShortName -Name "Google.Apis.Something.v1.SomeType" -ApiRootNameSpace "Google.Apis.Something.v1" | Should BeExactly "SomeType"

        Get-ApiPropertyTypeShortName -Name "Google.Apis.Something.v1.SomeNamespace.SomeType" -ApiRootNameSpace "Google.Apis.Something.v1" | Should BeExactly "SomeNamespace.SomeType"

        Get-ApiPropertyTypeShortName -Name "Google.Apis.Something.v1.SomeType+SomeInnerType" -ApiRootNameSpace "Google.Apis.Something.v1" | Should BeExactly "SomeType.SomeInnerType"
    }

    it "handles incorrect root namespaces" {
        Get-ApiPropertyTypeShortName -Name "Google.Apis.Something.v1.SomeType" -ApiRootNameSpace 
            "Google.Apis.Something.v2" | Should BeExactly "Google.Apis.Something.v1.SomeType"
    }
}

Describe New-BasicTypeStruct {
    it "handles null or incorrect input" {
        {New-BasicTypeStruct $null} | Should Throw
        {New-BasicTypeStruct "not in the type set"} | Should Throw
        {New-BasicTypeStruct 1} | Should Throw
    }

    it "creates expected results" {
        $TypeResults = @{
            "string" = "System.String"
            "bool" = "System.Boolean"
            "int32" = "System.Int32"
            "int64" = "System.Int64"
            "uint64" = "System.UInt64"
            "void" = "void"
        }

        foreach ($Key in $TypeResults.Keys) {
            $Result = New-BasicTypeStruct $Key
            $Result.FullyQualifiedType | Should BeExactly $TypeResults[$Key]
            $Result -is "ApiPropertyTypeStruct" | Should Be $True
        }
    }
}

Describe Get-ApiPropertyTypeBasic {
    Mock New-BasicTypeStruct {return $Type}

    it "handles null or incorrect type" {
        #TODO: what types are expected by RefType?
        {Get-ApiPropertyTypeBasic -RefType $null -ApiRootNameSpace "NotNull"} | Should Throw
        {Get-ApiPropertyTypeBasic -RefType "NotNull" -ApiRootNameSpace $null} | Should Throw
        {Get-ApiPropertyTypeBasic -RefType "NotNull" -ApiRootNameSpace ""} | Should Throw
        {Get-ApiPropertyTypeBasic -RefType "NotNull" -ApiRootNameSpace [PsCustomObject]@{}} | Should Throw
    }

    it "returns basic types" {
        $TypeResults = @{
            "System.String" = "string" 
            "String" = "string"
            "System.Int32" = "int32"
            "Int32" = "int32"
            "System.Boolean" = "bool"
            "Boolean" = "bool"
            "System.Int64" = "int64"
            "Int64" = "int64"
            "System.UInt64" = "uint64"
            "UInt64" = "uint64"
        }

        foreach ($Key in $TypeResults.Keys) {
            $RefType = [PsCustomObject]@{FullName = $Key}
            $Result = Get-ApiPropertyTypeBasic -RefType $RefType -ApiRootNameSpace "Something"
            $Result | Should BeExactly $TypeResults[$Key]
        }
    }

    it "returns standard types" {
        $ApiNamespace = "Google.Apis.v1"
        $Type = "SomeType"
        $FullType = $ApiNamespace + "." + $Type

        $RefType = [PsCustomObject]@{ FullName = $FullType }

        $Result = Get-ApiPropertyTypeBasic -RefType $RefType -ApiRootNameSpace $ApiNameSpace

        $Result.Type | Should BeExactly $Type
        $Result.FullyQualifiedType | Should BeExactly $FullType
        $Result.HelpDocShortType | Should BeExactly $Type
        $Result.HelpDocLongType | Should BeExactly $FullType
    }

    it "returns standard inner types" {
        $ApiNamespace = "Google.Apis.v1"
        $MainType = "SomeType"
        $InnerType = "InnerType"
        $FullTypePlus = $ApiNamespace + "." + $MainType + "+" + $InnerType
        $FullTypeDot = $ApiNamespace + "." + $MainType + "." + $InnerType

        $RefType = [PsCustomObject]@{ FullName = $FullTypePlus }

        $Result = Get-ApiPropertyTypeBasic -RefType $RefType -ApiRootNameSpace $ApiNameSpace

        $Result -is "ApiPropertyTypeStruct" | Should Be $true
        $Result.Type | Should BeExactly ($MainType + "." + $InnerType)
        $Result.FullyQualifiedType | Should BeExactly $FullTypeDot
        $Result.HelpDocShortType | Should BeExactly $InnerType
        $Result.HelpDocLongType | Should BeExactly $FullTypeDot
    }
}

Describe Get-ApiPropertyType {
    $BasicTypeReturn = "BasicTypeReturn"
    mock Get-ApiPropertyTypeBasic { return $BasicTypeReturn }

    BeforeEach {
        $MockProperty = New-Object ApiMethodProperty
        $MockGenericTypeArgument = [PsCustomObject]@{
            PSTypeName = 'System.RuntimeType'
            Name = "Boolean"
        }
        $MockGenericTypeArgument.PsObject.TypeNames.Insert(1,"System.Type")
        $MockRuntimeType = [PsCustomObject]@{
            PSTypeName = 'System.Type'
            Name = "SomeType"
            FullName = "Google.Apis.Something.v1.SomeType"
            DeclaringType = [PsCustomObject]@{
                IsGenericType = $false
            }
            UnderlyingSystemType = [PsCustomObject]@{
                FullName = "Google.Apis.Something.v1.SomeUnderlyingType"
            }
            GenericTypeArguments = @(
                $MockGenericTypeArgument
            )
        }
        $MockApiNamespace = "Google.Apis.Something.v1"
        
    }

    context "error handling" {
        it "handles null or incorrect input" {
            
            #parameter set 1
            {Get-ApiPropertyType -Property $null -ApiRootNameSpace $MockApiNamespace} | Should Throw
            {Get-ApiPropertyType -Property "Foo" -ApiRootNameSpace $MockApiNamespace} | Should Throw
            {Get-ApiPropertyType -Property $MockProperty -ApiRootNameSpace $Null} | Should Throw
            {Get-ApiPropertyType -Property $MockProperty -ApiRootNameSpace ""} | Should Throw
            {Get-ApiPropertyType -Property $MockProperty -ApiRootNameSpace [PsCustomObject]@{}} | Should Throw

            #parameter set 2
            {Get-ApiPropertyType -RuntimeType $null -ApiRootNameSpace $MockApiNamespace} | Should Throw
            {Get-ApiPropertyType -RuntimeType "Bar" -ApiRootNameSpace $MockApiNamespace} | Should Throw
            {Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $null} | Should Throw
            {Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace ""} | Should Throw
            {Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace [PsCustomObject]@{}} | Should Throw
        }

        it "throws on unexpected property set ref type" {
            {Get-ApiPropertyType -Property $MockProperty -ApiRootNameSpace $MockApiNamespace} | Should Throw "No Sub RefType found on Property"
        }

        it "throws for missing ref type full name" {
            $MockRuntimeType.FullName = $null
            
            {Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace} | Should Throw "ReflectionTest: RefType FullName is null, please revise"
        }
    }

    context "null returns" {
        it "returns null for subclass or generic without generic type, or empty reftype name" {
            $MockRuntimeType.UnderlyingSystemType.FullName += "+SomeInnerType"
            $MockRuntimeType.DeclaringType.IsGenericType = $true
            $Results = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            $Results | Should BeNullOrEmpty
        }

        it "returns null for reftype with empty name and fullname" {
            $MockRuntimeType.Name = ""
            $MockRuntimeType.FullName = ""
            $Results1 = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            $Results1 | Should BeNullOrEmpty

            $MockRuntimeType.Name = $null
            $MockRuntimeType.FullName = $null
            $Results2 = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            $Results2 | Should BeNullOrEmpty
        }
    }

    context "mock recursive call for single generic types"{
        
        $ReturnedInnerType = New-Object ApiPropertyTypeStruct -Property @{
            Type = "objtype"
            FullyQualifiedType = "FQType"
            HelpDocShortType = "HelpShortType"
            HelpDocLongType = "HelpLongType"
        }

        mock Get-ApiPropertyType {return $ReturnedInnerType} -ParameterFilter {$RuntimeType -eq $MockGenericTypeArgument}

        it "handles generic repeatable`1 types" {
            $MockRuntimeType.Name = "Repeatable``1"
            $Result = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            
            Assert-MockCalled "Get-ApiPropertyType" -Times 1

            $Result.Type | Should BeExactly ("Google.Apis.Util.Repeatable<{0}>" -f $ReturnedInnerType.Type)
            $Result.FullyQualifiedType | Should BeExactly ("Google.Apis.Util.Repeatable<{0}>" -f $ReturnedInnerType.FullyQualifiedType)
            $Result.HelpDocShortType | Should BeExactly ("{0}[]" -f $ReturnedInnerType.HelpDocShortType)
            $Result.HelpDocLongType | Should BeExactly ("{0}[]" -f $ReturnedInnerType.FullyQualifiedType)

            $Result.InnerTypes.Count | Should Be 1
            $ReturnedInnerType | Should BeIn $Result.InnerTypes
        }

        it "handles generic nullable`1 types" {
            #TODO line 1105
            $MockRuntimeType.Name = "Nullable``1"
            $Result = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            
            Assert-MockCalled "Get-ApiPropertyType" -Times 1

            $Result.Type | Should BeExactly ("{0}?" -f $ReturnedInnerType.Type)
            $Result.FullyQualifiedType | Should BeExactly ("System.Nullable<{0}>" -f $ReturnedInnerType.FullyQualifiedType)
            $Result.HelpDocShortType | Should BeExactly $ReturnedInnerType.HelpDocShortType
            $Result.HelpDocLongType | Should BeExactly $ReturnedInnerType.FullyQualifiedType

            $Result.InnerTypes.Count | Should Be 1
            $ReturnedInnerType | Should BeIn $Result.InnerTypes
        }

        it "handles other generic types" {
            $MockRuntimeType.Name = "SomeType+SomeGeneric``1"
            $Result = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace
            
            Assert-MockCalled "Get-ApiPropertyType" -Times 1

            $ResultType = "SomeType.SomeGeneric<{0}>" -f $ReturnedInnerType.Type

            $Result.Type | Should BeExactly $ResultType
            $Result.FullyQualifiedType | Should BeExactly $ResultType
            $Result.HelpDocShortType | Should BeExactly $ResultType
            $Result.HelpDocLongType | Should BeExactly $ResultType

            $Result.InnerTypes.Count | Should Be 1
            $ReturnedInnerType | Should BeIn $Result.InnerTypes
        }
    }

    context "mock recursive calls for multigeneric types" {
        $ReturnedInnerType1 = New-Object ApiPropertyTypeStruct -Property @{
            Type = "objtype1"
            FullyQualifiedType = "FQType1"
            HelpDocShortType = "HelpShortType1"
            HelpDocLongType = "HelpLongType1"
        }

        $ReturnedInnerType2 = New-Object ApiPropertyTypeStruct -Property @{
            Type = "objtype2"
            FullyQualifiedType = "FQType2"
            HelpDocShortType = "HelpShortType2"
            HelpDocLongType = "HelpLongType2"
        }

        $MockGenericTypeArgument2 = [PsCustomObject]@{
            PSTypeName = 'System.RuntimeType'
            Name = "String"
        }
        $MockGenericTypeArgument2.PsObject.TypeNames.Insert(1,"System.Type")

        mock Get-ApiPropertyType {return $ReturnedInnerType1} -ParameterFilter {$RuntimeType -eq $MockGenericTypeArgument}

        mock Get-ApiPropertyType {return $ReturnedInnerType2} -ParameterFilter {$RuntimeType -eq $MockGenericTypeArgument2}

        it "handles multiple generic inner types" {
            $MockRuntimeType.GenericTypeArguments += $MockGenericTypeArgument2

            $MockRuntimeType.Name = "SomeClass+MultiGeneric``1"
            $MockRuntimeType.FullName = "Google.Apis.Something.v1.SomeClass+MultiGeneric``1"

            $Result = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace

            Assert-MockCalled "Get-ApiPropertyType" -Times 2

            $Result.Type | Should BeExactly ("SomeClass.MultiGeneric<{0}, {1}>" -f $ReturnedInnerType1.Type, $ReturnedInnerType2.Type)
            $Result.FullyQualifiedType | Should BeExactly ("Google.Apis.Something.v1.SomeClass.MultiGeneric<{0}, {1}>" -f $ReturnedInnerType1.FullyQualifiedType, $ReturnedInnerType2.FullyQualifiedType)
            $Result.HelpDocShortType | Should BeExactly $Result.Type
            $Result.HelpDocLongType | Should BeExactly $Result.FullyQualifiedType

            $Result.InnerTypes.Count | Should Be 2
            $ReturnedInnerType1 | Should BeIn $Result.InnerTypes
            $ReturnedInnerType2 | Should BeIn $Result.InnerTypes
        }
    }

    context "other standard method calls" {
        it "handles non-generic types" {
            $Results = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace

            $Results | Should Be $BasicTypeReturn
        }

        it "handles `$RuntimeType type of System.RuntimeType" {
            $MockRuntimeType.PsObject.TypeNames[0] = "System.RuntimeType"
            $Results = Get-ApiPropertyType -RuntimeType $MockRuntimeType -ApiRootNameSpace $MockApiNamespace

            $Results | Should Be $BasicTypeReturn
        }
    }
}

Describe New-ApiMethodProperty {
    BeforeEach {
        $MockPropertyTypeResultFromRuntime = New-Object ApiPropertyTypeStruct -Property @{
            HelpDocLongType = "FromRuntime"
        }
        $MockPropertyTypeResultFromProperty = New-Object ApiPropertyTypeStruct -Property @{
            HelpDocLongType = "FromProperty"
        }
        mock Get-ApiPropertyType {return $MockPropertyTypeResultFromRuntime} -ParameterFilter {$RuntimeType -ne $null}
        mock Get-ApiPropertyType {return $MockPropertyTypeResultFromProperty} -ParameterFilter {$Property -ne $null}
        mock Clean-CommentString {return $String}
        mock New-ApiClass {return "NewApiClass"}

        $MockMethodDiscoveryObj = [PsCustomObject]@{
            Name = "Paramname"
            Description = "Some Description"
            Required = "false"
        }
        $WrongMethodDiscoveryObj = [PsCustomObject]@{Name="Wrong"}
        $MockMethod = New-Object ApiMethod -Property @{
            Api = New-Object Api -Property @{
                RootNamespace = "SomeRootNamespace"
            }
            DiscoveryObj = [PsCustomObject]@{
                parameters = @{
                    $MockMethodDiscoveryObj.Name = $MockMethodDiscoveryObj
                    "Wrong" = $WrongMethodDiscoveryObj
                }
            }
        }
        $MockProperty = [PsCustomObject]@{
            PSTypeName = 'System.Type'
            Name = $MockMethodDiscoveryObj.Name
            ParameterType = [PsCustomObject]@{
                ImplementedInterfaces = [PsCustomObject]@{
                    Name = @("Foo","Bar")
                }
            }
        }
    }

    it "handles null or incorrect input" {
        {New-ApiMethodProperty -Method $null -Property $MockProperty} | Should Throw
        {New-ApiMethodProperty -Method "" -Property $MockProperty} | Should Throw
        {New-ApiMethodProperty -Method $MockMethod -Property $null} | Should Throw
        {New-ApiMethodProperty -Method $MockMethod -Property ""} | Should Throw
    }

    it "handles null Discovery Description" {
        $MockMethodDiscoveryObj.Description = $null
        {New-ApiMethodProperty -Method $MockMethod -Property $MockProperty} | Should Not Throw
    }

    it "handles null Discovery Object" {
        $MockMethod.DiscoveryObj = $null
        {New-ApiMethodProperty -Method $MockMethod -Property $MockProperty} | Should Not Throw
    }

    it "returns standard result" {
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Method | Should BeExactly $MockMethod
        $Result.Api | Should BeExactly $MockMethod.Api
        $Result.Name | Should BeExactly $MockMethodDiscoveryObj.Name
        $Result.NameLower | Should BeExactly $MockMethodDiscoveryObj.Name.ToLower()
        $Result.ReflectedObj | Should BeExactly $MockProperty
        $Result.DiscoveryObj | Should BeExactly $MockMethodDiscoveryObj
        $Result.DiscoveryObj | Should Not Be $WrongMethodDiscoveryObj
        $Result.Type | Should BeExactly $MockPropertyTypeResultFromProperty
        $Result.Type | Should Not Be $MockPropertyTypeResultFromRuntime
        $Result.Description | Should BeExactly $MockMethodDiscoveryObj.Description
        $Result.Required | Should Be $false
        $Result.Method.SupportsMediaUpload | Should Be $false
        $Result.Method.HasBodyParameter | Should Be $false
        $Result.Method.BodyParameter | Should BeNullOrEmpty
        $Result.ShouldIncludeInTemplates | Should Be $True
        $Result.IsSchemaObject | Should Be $false
        $Result.SchemaObject | Should BeNullOrEmpty
    }

    it "adjusts for RuntimeType property objects" {
        $MockProperty.PsObject.TypeNames[0] = "System.RuntimeType"

        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Type | Should BeExactly $MockPropertyTypeResultFromRuntime
        $Result.Type | Should Not Be $MockPropertyTypeResultFromProperty
    }

    it "adjusts for IMediaDownloader" {
        $MockPropertyTypeResultFromProperty.FullyQualifiedType = "Something.Download.IMediaDownloader"
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Method.SupportsMediaDownload | Should Be $true
        $Result.ShouldIncludeInTemplates | Should Be $false
    }

    it "adjusts for null types" {
        $MockPropertyTypeResultFromProperty = $null
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Method.SupportsMediaDownload | Should Be $false
        $Result.ShouldIncludeInTemplates | Should Be $false
    }

    it "adjusts for null descriptions" {
        $MockMethodDiscoveryObj.Description = $null
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Description | Should BeLike ("Description*{0}*unavailable." -f $MockPropertyTypeResultFromProperty.HelpDocLongType)


        $MockMethodDiscoveryObj.Description = " "
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.Description | Should BeLike ("Description*{0}*unavailable." -f $MockPropertyTypeResultFromProperty.HelpDocLongType)
    }

    it "adjusts for schema objects" {
        $MockProperty.ParameterType.ImplementedInterfaces.Name += "IDirectResponseSchema"
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.IsSchemaObject | Should Be $true
        $Result.SchemaObject | Should Be "NewApiClass"
        $Result.Description | Should BeExactly $MockMethodDiscoveryObj.Description
        $Result.Method.HasBodyParameter | Should Be $false
        $Result.Method.BodyParameter | Should BeNullOrEmpty
    }

    it "adjusts for schema objects when Body" {
        $MockProperty.Name = "Body"
        $MockMethodDiscoveryObj.Name = "Body"
        $MockMethod.DiscoveryObj.parameters["Body"] = $MockMethodDiscoveryObj
        $MockProperty.ParameterType.ImplementedInterfaces.Name += "IDirectResponseSchema"
        
        $Result = New-ApiMethodProperty -Method $MockMethod -Property $MockProperty
        $Result.IsSchemaObject | Should Be $true
        $Result.SchemaObject | Should Be "NewApiClass"
        $Result.Description | Should BeLike "An object of type*"
        $Result.Method.HasBodyParameter | Should Be $true
        $Result.Method.BodyParameter | Should Be $Result
    }
}

Describe New-ApiClass {
    $MockReflectedObject = [PsCustomObject]@{
        PSTypeName = "System.Type"
        Name = "ReflectedName"
        DeclaredProperties = @(
            [PSCustomObject]@{
                PSTypeName = "System.PropertyType"
                Name = "ETag"
            },
            [PSCustomObject]@{
                PSTypeName = "System.PropertyType"
                Name = "Fizz"
            }
        )
    }

    $TypeStructReturnObj = New-Object ApiPropertyTypeStruct -Property @{
        Type = "ReturnType"
    }

    $SchemaDictObj = "SomeObj"

    $MockDiscoveryObj = [PSCustomObject]@{
        Description = "Discovery Description"
    }

    $MockApi = New-Object Api -Property @{
        SchemaObjectsDict = @{
            #$TypeStructReturnObj.Type = $SchemaDictObj
        }
        DiscoveryObj = [PSCustomObject]@{
            schemas = @{
                $MockReflectedObject.Name = $MockDiscoveryObj
            }
        }
    }

    Mock Get-ApiPropertyType {return $TypeStructReturnObj}
    Mock Clean-CommentString {return $String}
    Mock Get-SchemaObjectProperty {return New-Object ApiMethodProperty}
    
    it "handles null or incorrect input" {
        {New-ApiClass -ReflectedObj $null -Api $MockApi} | Should Throw
        {New-ApiClass -ReflectedObj "" -Api $MockApi} | Should Throw
        {New-ApiClass -ReflectedObj $MockReflectedObject -Api $null} | Should Throw
        {New-ApiClass -ReflectedObj $MockReflectedObject -Api ""} | Should Throw
    }

    it "returns expected" {
        $Result = New-ApiClass -ReflectedObj $MockReflectedObject -Api $MockApi
        $Result.Api | Should BeExactly $MockApi
        $Result.ReflectedObj | Should BeExactly $MockReflectedObject
        $Result.Name | Should BeExactly $MockReflectedObject.Name
        $Result.DiscoveryObj | Should BeExactly $MockDiscoveryObj
        $Result.Type | Should BeExactly $TypeStructReturnObj
        $Result.Description | Should BeExactly $MockDiscoveryObj.Description
        $Result | Should BeIn $Result.Api.SchemaObjects
        $TypeStructReturnObj.Type | Should BeIn $Result.Api.SchemaObjectsDict.Keys
        $Result.Api.SchemaObjectsDict[$TypeStructReturnObj.Type] | Should BeExactly $Result

        Assert-MockCalled -CommandName "Get-SchemaObjectProperty" -Times 1
        $Result.Properties.Count | Should BeExactly 1
        "ETag" | Should Not BeIn $Result.Properties.Name
    }
}

Describe Get-SchemaObjectProperty  {

    $MockProperty = [PSCustomObject]@{
        PSTypeName = "System.PropertyType"
        Name = "PropertyName"
        PropertyType = [PSCustomObject]@{
            PSTypeName = "System.Type"
            ImplementedInterfaces = @(
                [PSCustomObject]@{
                    Name = "Foo"
                }
            )
        }
    }

    $MockApi = New-Object Api -Property @{RootNamespace = "SomeNamespace"}

    $MockApiClassDiscoveryObj = [PSCustomObject]@{
        Description = "DiscoveryDescription"
    }
    $MockApiClass = New-Object ApiClass -Property @{
        DiscoveryObj = [PSCustomObject]@{
            properties = @{
                $MockProperty.Name = $MockApiClassDiscoveryObj
            }
        }
    }

    $MockPropertyTypeReturn = "SomePropertyTypeReturn"
    $MockNewApiClassReturn = "SomeApiClassReturn"

    mock  Get-ApiPropertyType {return $MockPropertyTypeReturn}
    mock Clean-CommentString {return $String}
    mock New-ApiClass {return $MockNewApiClassReturn}

    it "handles null or incorrect input" {
        {Get-SchemaObjectProperty -Property $null -Api $MockApi -ApiClass $MockApiClass} | Should Throw
        {Get-SchemaObjectProperty -Property "" -Api $MockApi -ApiClass $MockApiClass} | Should Throw
        {Get-SchemaObjectProperty -Property $MockProperty -Api $null -ApiClass $MockApiClass} | Should Throw
        {Get-SchemaObjectProperty -Property $MockProperty -Api "" -ApiClass $MockApiClass} | Should Throw
        {Get-SchemaObjectProperty -Property $MockProperty -Api $MockApi -ApiClass $null} | Should Throw
        {Get-SchemaObjectProperty -Property $MockProperty -Api $MockApi -ApiClass ""} | Should Throw
    }

    it "returns expected" {
        $Result = Get-SchemaObjectProperty -Property $MockProperty -Api $MockApi -ApiClass $MockApiClass
        $Result.Name | Should BeExactly $MockProperty.Name
        $Result.Api | Should BeExactly $MockApi
        $Result.DiscoveryObj | Should BeExactly $MockApiClassDiscoveryObj
        $Result.ReflectedObj | Should BeExactly $MockProperty
        $Result.Type | Should BeExactly $MockPropertyTypeReturn
        $Result.Description | Should BeExactly $MockApiClassDiscoveryObj.Description

        $Result.IsSchemaObject | Should Be $false
        $Result.SchemaObject | Should BeNullOrEmpty

        $Result.ImplementedInterfaces
    }

    it "handles IDirectResponseSchema" {
        $MockProperty.PropertyType.ImplementedInterfaces += [PSCustomObject]@{ Name = "IDirectResponseSchema" }
        $Result = Get-SchemaObjectProperty -Property $MockProperty -Api $MockApi -ApiClass $MockApiClass
        $Result.IsSchemaObject | Should Be $true
        $Result.SchemaObject | Should BeExactly $MockNewApiClassReturn
    }
}

Describe Get-ApiMethodReturnType {
    $Assembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation")
    $Method = $Assembly.ExportedTypes `
        | Select-Object -ExpandProperty DeclaredMethods `
        | Where-Object {$_ -is [System.Reflection.MethodInfo]} `
        | Where-Object Name -eq "get_RuntimeDefinedParameters" `
        | Select-Object -First 1

    it "handles null or incorrect input" {
        {Get-ApiMethodReturnType -Method $null} | Should Throw
        {Get-ApiMethodReturnType -Method ""} | Should Throw
        {Get-ApiMethodReturnType -Method $Method -UseReturnTypeGenericInt "Foo"} | Should Throw
    }

    it "returns null with out of bounds" {
        Get-ApiMethodReturnType -Method $Method -UseReturnTypeGenericInt 2 | Should BeNullOrEmpty
    }

    it "returns expected" {
        $Result1 = Get-ApiMethodReturnType -Method $Method
        $Result1.FullName | Should BeExactly "System.String"
        Test-ObjectType "System.RuntimeType" $Result1 | Should Be $true

        $Result2 = Get-ApiMethodReturnType -Method $Method -UseReturnTypeGenericInt 0
        $Result1 | Should BeExactly $Result2

        $Result3 = Get-ApiMethodReturnType -Method $Method -UseReturnTypeGenericInt 1
        $Result3.FullName | Should BeExactly "System.Management.Automation.RuntimeDefinedParameter"
    }
}

Describe Import-GShellAssemblies {
    BeforeAll {
        $TestPath = "TestDrive:\someFile.dll"
        New-Item -Path $TestPath -ItemType File
    }

    BeforeEach {

        $MockLibraryIndex = [PSCustomObject]@{
            Name = "SomeName"
            PSTypeName = "LibraryIndex"
        }

        $Dependency1 = [PSCustomObject]@{
            Name = "Some.Library.v1"
            Versions = "1.30.0"
        }

        $Dependency2 = [PSCustomObject]@{
            Name = "Some.Other.Library.v1"
            Versions = -1
        }

        $MockLibraryIndexVersion = [PSCustomObject]@{
            dllPath = $TestPath
            Dependencies = @($Dependency1,$Dependency2)
        }

        $MockLibraryIndexVersionReturn = [PSCustomObject]@{
            dllPath = $TestPath
            Dependencies = @()
        }
    }

    mock Get-LatestVersionFromRange {return $VersionRange}
    mock Get-LibraryIndexLibVersionLatest {return $MockLibraryIndexVersionReturn}
    mock Get-LibraryIndexLibVersion {return $MockLibraryIndexVersionReturn}
    mock Import-GShellAssemblies {return $null} -ParameterFilter {$LibraryIndexVersionInfo -eq $MockLibraryIndexVersionReturn}
    
    $MockImportAssemblyReturn = "MockAssembly"
    mock Import-Assembly {return $MockImportAssemblyReturn }

    it "handles null or incorrect input" {
        {Import-GShellAssemblies -LibraryIndex $null -LibraryIndexVersionInfo $MockLibraryIndexVersion}
        {Import-GShellAssemblies -LibraryIndex "" -LibraryIndexVersionInfo $MockLibraryIndexVersion}
        {Import-GShellAssemblies -LibraryIndex $MockLibraryIndex -LibraryIndexVersionInfo $null}
        {Import-GShellAssemblies -LibraryIndex $MockLibraryIndex -LibraryIndexVersionInfo ""}
    }

    it "handles correct input and recursion" {
        $Result = Import-GShellAssemblies -LibraryIndex $MockLibraryIndex -LibraryIndexVersionInfo $MockLibraryIndexVersion
        $Result | Should BeExactly $MockImportAssemblyReturn
        Assert-MockCalled -CommandName Get-LatestVersionFromRange -Times 2
        Assert-MockCalled -CommandName Get-LibraryIndexLibVersionLatest -Times 1
        Assert-MockCalled -CommandName Get-LibraryIndexLibVersion -Times 1
        Assert-MockCalled -CommandName Import-GShellAssemblies -Times 1
    }

    it "handles malformed dllPath" {
        $MalformedDlls = @($null, "", "missing", "something_._")
        foreach ($M in $MalformedDlls) {
            $MockLibraryIndexVersion.dllPath = $M
            $Result = Import-GShellAssemblies -LibraryIndex $MockLibraryIndex -LibraryIndexVersionInfo $MockLibraryIndexVersion
            $Result | Should BeNullOrEmpty
        }
    }
}