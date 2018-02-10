<#
To make sure Git is working:
1) Make sure git for windows is installed (don't need the fancy program thought). Make sure it's in the PATH variable.
2) Build out the file structure of .ssh etc used for Git as in this: https://serverfault.com/a/198691
3) Follow steps 1, 3, 4 and 5 from this: https://stackoverflow.com/a/29908140/792032
4) Relaunch PoSh if it's open to get that all working.
#>


#TODO: put this... somewhere else? main probably?
if ($null -eq (git --version)) { throw "Git doesn't appear to be installed, uhoh!" }

#wrapping git functions from command line to force providing a path and to throw any errors caught
function Call-Git ($RepoPath, $Commands) {

    $commandBlock = $Commands -join " "

    $scriptBlock = [scriptblock]::create(
        "git -C $RepoPath $commandBlock 2>&1"
    )

    $gitcall = Invoke-Command -ScriptBlock $scriptBlock

    $Errors = New-Object System.Collections.ArrayList
    $Output = New-Object System.Collections.ArrayList

    foreach ($line in $gitcall) {
        if ($line -is [System.Management.Automation.ErrorRecord] -and $line -match "fatal:") {
            $Errors.Add($line.Exception.Message) | Out-Null
            $Output.Add($line.Exception.Message) | Out-Null
        } else {
            $Output.Add($line) | Out-Null
        }
    }

    if ($Errors.Count -gt 0) {
        #TODO:  what if  it's an array of error records!
        throw ($Errors -join "`r`n")
    } else {
        return ($Output -join "`r`n")
    }
}

function Get-GitStatus ($RepoPath) {
    Call-Git -RepoPath $RepoPath -Commands "status"
}

function Add-GitFile {
    param (
        [Parameter(Position=0)]
        [string]$RepoPath,

        [Parameter(Position=1,ParameterSetName="File")]
        [string]$FilePath,

        [Parameter(Position=1,ParameterSetName="Directory")]
        [string]$DirPath,

        [Parameter(Position=1,ParameterSetName="All")]
        [Switch]$All
    )

    $Commands = New-Object System.Collections.ArrayList
    $Commands.Add("add") | Out-Null

    switch ($PsCmdlet.ParameterSetName) {
        "File" {$Commands.Add($FilePath) | Out-Null}
        "Directory" {$Commands.Add($DirPath) | Out-Null}
        "All" {$Commands.Add("-A") | Out-Null}
    }

    Call-Git -RepoPath $RepoPath -Commands $Commands
}

function Run-GitCommit ($RepoPath, $Message, [switch]$CommitAllChanged, [switch]$Quiet) {
    $Commands = New-Object System.Collections.ArrayList
    $Commands.AddRange(@("commit","-m","`"$Message`"")) | Out-Null
    
    if ($CommitAllChanged) {
        $Commands.Add("-a") | Out-Null
    }

    if ($Quiet) {
        $Commands.Add("-q") | Out-Null
    }

    Call-Git -RepoPath $RepoPath -Commands $Commands
}

function Run-GitPush ($RepoPath, $Branches, [switch]$Quiet){
    $Commands = New-Object System.Collections.ArrayList
    $Commands.Add("push") | Out-Null

    if ($null -ne $Branches) {
        foreach ($Branch in $Branches) {
            $Commands.Add($Branch) | Out-Null    
        }
    }

    if ($Quiet) {
        $Commands.Add("-q") | Out-Null
    }

    Call-Git -RepoPath $RepoPath -Commands $Commands
}

function Run-GitPull ($RepoPath, [switch]$All) {
    $Commands = New-Object System.Collections.ArrayList
    $Commands.Add("pull") | Out-Null
    if ($All) {
        $Commands.Add("--all") | Out-Null
    }
    Call-Git -RepoPath $RepoPath -Commands $Commands
}

<#
$Repo = "$env:USERPROFILE\Documents\GshellAutomationTest.wiki"

try {
    Add-GitFile $Repo -All

    Run-GitCommit $Repo "Testing Cmdlet Commit more" -CommitAllChanged

    Run-GitPull $Repo -All

    Run-GitPush $Repo "origin"
} catch {
    "Error!"
    $_.Exception.Message
}
#>