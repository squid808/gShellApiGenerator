. ($MyInvocation.InvocationName -replace "Tests.ps1","ps1")

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