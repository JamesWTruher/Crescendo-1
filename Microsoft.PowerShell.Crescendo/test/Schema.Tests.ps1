Describe "Schema tests" {
	BeforeAll {
		$module = Get-Module Microsoft.PowerShell.Crescendo
		$schemaPath = Join-Path -Path $module.ModuleBase -ChildPath Schemas -AdditionalChildPath 2022-06
		$schemaObject = Get-Content $schemaPath | ConvertFrom-Json
		# convert the schema to xml to make it easier to query
		$schemaXml = [xml][newtonsoft.json.jsonconvert]::DeserializeXNode((get-content -raw $schemaPath), "Root").ToString()

		$commandObject = & $module {[command]}
		$parameterObject = & $module {[parameterinfo]}
		$usageObject = & $module {[usageinfo]}
		$exampleObject = & $module {[exampleinfo]}
		$outputObject = & $module {[outputhandler]}
		$elevationObject = & $module {[elevation]}
	}

	Context 'Each element should have a description' {
		BeforeAll {
			$xPath = @()
			$cmdXPath = "/Root/definitions/command"
			$xPath += $cmdXPath
			$xPath += $commandObject.GetProperties().Name.foreach({"$cmdXPath/properties/$_"})

			$usageXPath = "/Root/definitions/command/properties/Usage"
			$xPath += $usageXPath
			$xPath += $usageObject.GetProperties().Name.foreach({"$usageXPath/properties/$_"})

			$exampleXPath = "/Root/definitions/command/properties/Examples"
			$xPath += $exampleXPath
			$xPath += $exampleObject.GetProperties().Name.foreach({"$exampleXPath/items/properties/$_"})

			$outputXPath = "/Root/definitions/command/properties/OutputHandlers"
			$xPath += $outputXPath
			$xPath += $outputObject.GetProperties().Name.foreach({"$outputXPath/items/properties/$_"})

			$elevationXPath = "/Root/definitions/command/properties/Elevation"
			$xPath += $elevationXPath
			$xPath += $elevationObject.GetProperties().Name.foreach({"$elevationXPath/properties/$_"})

			$parameterXPath = "/Root/definitions/parameter"
			$xPath += $parameterXPath
			$xPath += $parameterObject.GetProperties().Name.foreach({"$parameterXPath/properties/$_"})
			$testCases = $xPath | ForEach-Object { @{ path = $_ } }
		}

		It "A description should be found for '<path>'." -TestCases $testCases {
			param ($path)
			$schemaXml.SelectSingleNode($path).description | Should -Not -BeNullOrEmpty
		}

		It "Each description for '<path>' should end with a period." -TestCases $testCases {
			param ($path)
			$schemaXml.SelectSingleNode($path).description[-1] | Should -Be "."
		}

	}

    Context "New schema version is supported" {
        BeforeAll {
            $badFile1 = "$PSScriptRoot/assets/badschema1.proxy.json"
            $badFile2 = "$PSScriptRoot/assets/badschema2.proxy.json"
            # it's not really bad, but we want to make sure it's not picked up
            $newFile3 = "$PSScriptRoot/assets/badschema3.proxy.json"
        }

		It "The 2022 schema should be supported" {
			{ Import-CommandConfiguration -file $newFile3 } | Should -Not -Throw
		}

        It "A configuration with an unsupported schema produces an error" {
			{ Import-CommandConfiguration -file $badFile1 } | Should -Throw "Unsupported schema version 2099-10"
        }

        It "A configuration without a schema produces a warning" {
			Import-CommandConfiguration -file $badFile2 -WarningVariable schemaWarn -WarningAction SilentlyContinue
			$schemaWarn | Should -match "Cannot determine schema version for .*badschema2.proxy.json"
		}
	}
}
