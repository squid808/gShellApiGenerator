Describe "Format-Json" {

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

Describe "Save-LibraryIndex" {

    $TestPath = "TestDrive:\library.json"
    $MockIndex = New-Object -Type PSObject
    $MockIndex | Add-Member -MemberType NoteProperty -Name "RootPath" -Value $TestPath
    $MockIndex | Add-Member -MemberType NoteProperty -Name "Libraries" -Value (New-Object psobject)

    Context "Null Object" {
        
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
            $result | Should -BeExactly @"
{
  "RootPath": "TestDrive:\\library.json",
  "Libraries": {
  }
}


"@
        }
    }
}
