. ($MyInvocation.MyCommand.Path -replace "Tests.","")

Describe Format-Json {

    It 'errors on null input' {
        {$null | Format-Json -ErrorAction Stop} | Should Throw "Cannot bind argument to parameter 'json' because it is an empty string."
    }

    It 'formats as expected' {
        #region HereStrings
        $stringin = @"
{
    "A":  1,
    "B":  [
{
               "C":  2
          },
          {
          "D": null
   }
      ]
}
"@

        $stringout = @"
{
  "A": 1,
  "B": [
    {
      "C": 2
    },
    {
      "D": null
    }
  ]
}

"@
        #endregion
        $stringin | Format-Json | Should -BeExactly $stringout
    }
}

Describe Load-LibraryIndexFile {
    #mock Get-Content {return "{}"}

    $TestDir = "TestDrive:\"
    $TestPath = $TestDir + "LibPaths.json"

    it "handles null or incorrect input" {
        {Load-LibraryIndexFile $null | Should Throw}
        {Load-LibraryIndexFile "" | Should Throw}
        {Load-LibraryIndexFile ($TestDir + "SomeInvalidPath\") | Should Throw}
    }

    it "handles no file" {
        $Result = Load-LibraryIndexFile -Path $TestDir
        Test-Path $TestPath | Should Be $true
        "RootPath" | Should BeIn $Result.PsObject.Properties.Name
        "LibraryIndex" | Should BeIn $Result.PsObject.TypeNames
        $Result.RootPath | Should BeExactly $TestPath
    }

    it "handles preexisting file" {
        Test-Path $TestPath | Should Be $true
        $Result = Load-LibraryIndexFile -Path $TestDir
        "RootPath" | Should BeIn $Result.PsObject.Properties.Name
        "LibraryIndex" | Should BeIn $Result.PsObject.TypeNames
        $Result.RootPath | Should BeExactly $TestPath
    }
}

Describe Save-LibraryIndex {

    $TestPath = "TestDrive:\library.json"
    $MockIndex = New-Object -Type PSObject
    $MockIndex | Add-Member -MemberType NoteProperty -Name "RootPath" -Value $TestPath
    $MockIndex | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)

    Context "Null Object" {
        Save-LibraryIndex -LibraryIndex $null
        $result = Get-Content $MockIndex.RootPath -Raw

        It "file exists" {
            test-path $MockIndex.RootPath | Should -BeExactly $true
        }

        It "has content" {
            $result | Should -BeExactly '{ }`r`n`r`n'
        }
    }

    Context "Null Root Path" {

    }

    Context "Working" {
        Save-LibraryIndex -LibraryIndex $MockIndex
        $result = Get-Content $MockIndex.RootPath -Raw

        It "file exists" {
            test-path $MockIndex.RootPath | Should -BeExactly $true
        }

        It "has content" {
            $result | Should -BeExactly '"{`r`n  "RootPath": "TestDrive:\\library.json",`r`n  "Libraries": {`r`n  }`r`n}`r`n`r`n'
        }
    }
}

