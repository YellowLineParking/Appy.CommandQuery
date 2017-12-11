$script:config = "Release"

task Clean{
	Clean-Folder $artifactsPath
	Clean-Folder TestResults
	Get-ProjectsForTask "Clean" | ForEach-Object {
		Clean-Folder "$($_.Name)\bin"
		Clean-Folder "$($_.Name)\obj"
	}
	New-Item $artifactsPath -Type directory -Force | Out-Null
}

task Compile {
	Get-ProjectsForTask "Compile" | ForEach-Object {
		Compile-Project $_.Name
	}

	Get-ProjectsForTask "Compile" | 
		Where { $_.Type -eq "EmbeddedWebJob" -or $_.Type -eq "StandaloneWebJob"} |
		ForEach-Object {
			Move-WebJob $_.Name $_.Config["Target"]  $_.Config["RunMode"]
		}
}

task Pack{
	Get-ProjectsForTask "Pack" | ForEach-Object {
		Pack-Project $_.Name			
	}
}

task Push{
	Get-ProjectsForTask "Push" | 
		ForEach-Object{ 
			Push-Package $_.Name $env:ylp_nugetPackageSource $env:ylp_nugetPackageSourceApiKey "409"
		}
}

task dev Clean, Compile, Pack
task ci dev, Push