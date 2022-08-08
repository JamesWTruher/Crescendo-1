Describe "The correct files are created when a module is created" {
    Context "proper configuration" {
        BeforeAll {
            $ModuleName = [guid]::NewGuid()
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile "${PSScriptRoot}/assets/FullProxy.json"
        }

        It "Should create the module manifest" {
            "${TESTDRIVE}/${ModuleName}.psd1" | Should -Exist
        }

        It "Should create the module code" {
            "${TESTDRIVE}/${ModuleName}.psm1" | Should -Exist
        }
    }

    Context "Configuration with fault" {
        BeforeAll {
            $ModuleName = [guid]::NewGuid()
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile "${PSScriptRoot}/assets/HandlerFault1.json" -ErrorAction SilentlyContinue
        }

        It "Should create the module manifest" {
            "${TESTDRIVE}/${ModuleName}.psd1" | Should -Exist
        }

        It "Should create the module code" {
            "${TESTDRIVE}/${ModuleName}.psm1" | Should -Exist
        }
    }

    Context "Supports -WhatIf" {
        It "Does not create a module file when WhatIf is used" {
            $ModuleName = "whatifmodule"
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile "${PSScriptRoot}/assets/FullProxy.json" -WhatIf
            Test-Path "${TESTDRIVE}/${ModuleName}*" | Should -Be $False
        }
    }

    Context "General Use" {
        It "Produces an error if the file exists" {
            $ModuleName = [guid]::NewGuid()
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile "${PSScriptRoot}/assets/FullProxy.json"
            # call it twice to produce the error
            { Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile "${PSScriptRoot}/assets/FullProxy.json" } | Should -Throw
        }

        It "Produces an error if the target platform is not allowed" {
            $ci =  New-CrescendoCommand -Verb Get -Noun Thing -OriginalName doesnotexist
            $ci.Platform = "incorrect"
            $mod = Get-Module Microsoft.PowerShell.Crescendo
            & $mod {
                $err = @()
                $ci = New-CrescendoCommand -verb get -noun thing
                $ci.platform = "zap"
                $result = Test-Configuration -Configuration $ci -err ([ref]$err)
                $result | Should -Be $false
                $err.Count | Should -Be 1
                $err[0].FullyQualifiedErrorId |  Should -Be "ParserError"
            }
        }

        It "Will produce an error if a script output handler cannot be found" {
            $cc = New-CrescendoCommand -verb get -noun thing -original notavailable
			$oh = new-outputhandler
			$oh.HandlerType = "Script"
			$oh.Handler = "doesnotexist"
            $oh.ParameterSetName = "Default"
			$cc.OutputHandlers += $oh
            $config = @{
                Commands = @($cc)
            }
            $tPath = "${TESTDRIVE}/badhandler"
            ConvertTo-Json -InputObject $config -Depth 10 | Out-File "${tPath}.json"
            Export-CrescendoModule -ConfigurationFile "${tPath}.json" -ModuleName "${tPath}" -ErrorVariable badHandler -ErrorAction SilentlyContinue
            $badHandler | Should -Not -BeNullOrEmpty
            $badHandler.FullyQualifiedErrorId | Should -Be "Microsoft.PowerShell.Commands.WriteErrorException,Export-CrescendoModule"
        }

        It "The psm1 file will contain the version of Crescendo that created it." {
            $ModuleName = [guid]::NewGuid()
            $configurationPath = "${PSScriptRoot}/assets/FullProxy.json"
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile $configurationPath
            $moduleContent = Get-Content "${TESTDRIVE}/${ModuleName}.psm1"
            $exportCmd = Get-Command Export-CrescendoModule
            $expectedModuleVersion = $exportCmd.Version
            $observedModuleVersion = $moduleContent[1] -replace ".* "
        }

        It "The psm1 file will contain the schema used when creating it." {
            $ModuleName = [guid]::NewGuid()
            $configurationPath = "${PSScriptRoot}/assets/FullProxy.json"
            Export-CrescendoModule -ModuleName "${TESTDRIVE}/${ModuleName}" -ConfigurationFile $configurationPath
            $moduleContent = Get-Content "${TESTDRIVE}/${ModuleName}.psm1"
            $expectedSchemaUrl = (Get-Content $configurationPath|ConvertFrom-Json).'$schema'
            $observedSchemaUrl = $moduleContent[2] -replace ".* "
            $observedSchemaUrl | Should -Be $expectedSchemaUrl
        }
    
        It "The Export-CrescendoModule default parameter set is 'file'" {
            (Get-Command Export-CrescendoModule).DefaultParameterSetName | Should -Be "file"
        }
    }

    Context "Export-CrescendoCommand can handle command objects" {
        BeforeAll {
            $commandNames = "Thing1", "Thing2", "Thing3"
            $Cmd1 = New-CrescendoCommand -Verb Get -Noun Thing1 -OriginalName "ls"
            $Cmd2 = New-CrescendoCommand -Verb Get -Noun Thing1 -OriginalName "ls"
            $Cmd3 = New-CrescendoCommand -Verb Get -Noun Thing3 -OriginalName "ls"
            $commandObjects = $Cmd1, $Cmd2, $Cmd3
        }

        It "A collection of command objects can still create a module." {
            $ModuleName = [guid]::NewGuid().ToString("N")
            Export-CrescendoModule -ModuleName $TESTDRIVE/$ModuleName -Command $commandObjects
            ${TESTDRIVE}/${ModuleName}.psd1 | Should -Exist
            ${TESTDRIVE}/${ModuleName}.psm1 | Should -Exist
            try {
                Import-Module "${TestDrive}/${ModuleName}"
                $observedNames = (Get-Command -Module ${ModuleName}).Name
            }
            finally {
                Remove-Module $ModuleName
            }
            $observedNames | Should -Be $commandNames
        }

        It "A collection of command objects can still create a module." {
            $ModuleName = [guid]::NewGuid().ToString("N")
            $commandObjects | Export-CrescendoModule -ModuleName $TESTDRIVE/$ModuleName
            ${TESTDRIVE}/${ModuleName}.psd1 | Should -Exist
            ${TESTDRIVE}/${ModuleName}.psm1 | Should -Exist
            try {
                Import-Module "${TestDrive}/${ModuleName}"
                $observedNames = (Get-Command -Module ${ModuleName}).Name
            }
            finally {
                Remove-Module $ModuleName
            }
            $observedNames | Should -Be $commandNames
        }

    }
}
