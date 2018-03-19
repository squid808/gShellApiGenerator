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

Describe "Clean-CommentString" {
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
        {Has-ObjProperty $null "foo" -ErrorAction Stop} | should -throw
    }
}
#endregion

#Create and return a known, false Assembly object for use in unit tests
function Get-TestAssemblyObject {
    $TestAssembly = [pscustomobject]@{
        PSTypeName = 'System.Reflection.Assembly'
        ImageRuntimeVersion = "v 1.2.3"
        FullName = "Google.Apis.Something.v1, Version=1.32.2.1139, Culture=neutral, PublicKeyToken=4b01fa6e34db77ab"
    }

    return $TestAssembly
}

function Get-TestRestJson {
    #TODO: Start here
    $TestJson = [pscustomobject]@{

    }
    return $TestJson
}

Describe New-Api {
    #TODO why is reflection.ps1 line 242 failing with PSInvalidCastException: Cannot convert the "Api" value of type "Api" to type "Api".
    
    mock ConvertTo-FirstLower {}
    mock Get-ApiStandardQueryParams {return @("StdQueryParamList")}
    mock Get-Resources {}
    mock Get-ApiScopes {}
    mock Get-ApiGShellBaseTypes {}

    $FakeAssembly = Get-TestAssemblyObject
    $FakeRestJson = Get-TestRestJson
    New-Api -Assembly $FakeAssembly -RestJson $FakeRestJson

    Assert-MockCalled ConvertTo-FirstLower
    Assert-MockCalled Get-ApiStandardQueryParams
    Assert-MockCalled Get-Resources
    Assert-MockCalled Get-ApiScopes
    Assert-MockCalled Get-ApiGShellBaseTypes
}