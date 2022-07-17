Describe "Packaging tests" {
    BeforeAll {
        $fileList = Get-ChildItem -File -Recurse "${PSScriptRoot}/.." |
            Where-Object {
            $_.Extension -eq ".json" -and
            $_.Name -notmatch "badschema" -and
            (Select-String '"\$schema"' $_.FullName)
            }
        $testCases = $fileList |
            Foreach-Object {
                $json = Get-Content $_.fullname | ConvertFrom-Json
                @{ FullName = $_.FullName -Replace ".*/Microsoft.PowerShell.Crescendo/"; JSON = $json }
            }
        $Schema1Url = 'https://aka.ms/PowerShell/Crescendo/Schemas/2021-11'
        $Schema2Url = 'https://aka.ms/PowerShell/Crescendo/Schemas/2022-06'
    }

    It "'<FullName>' references schema '$Schema1Url'" -TestCases $testCases {
        param ([string]$FullName, [object]$JSON )
        $JSON.'$schema' | Should -Be $Schema1Url
    }

    It "'$Schema1Url' is active" {
        $schema = Invoke-RestMethod $Schema1Url
        $schema.title | Should -Be "JSON schema for PowerShell Crescendo files"
    }

    It "'$Schema2Url' is active" -Pending {
        $schema = Invoke-RestMethod $Schema2Url
        $schema.title | Should -Be "JSON schema for PowerShell Crescendo files"
    }
}
