#region Variables

$script:artifactsPath = "artifacts"

$script:prereleaseDate = $(Get-Date).ToString("yyMMddHHmmss");

#endregion

#region General
function Get-PackagePath($packageId, $project) {
	if (!(Test-Path "$project\packages.config")) {
		throw "Could not find a packages.config file at $project"
	}
	
	[xml]$packagesXml = Get-Content "$project\packages.config"
	$package = $packagesXml.packages.package | Where { $_.id -eq $packageId }
	if (!$package) {
		throw "$packageId is required in $project, but it is not installed. Please install $packageId in $project"
	}
	return "$packagesPath\$($package.id).$($package.version)"
}

$script:projectConfig = $null
function Get-ProjectsForTask($task){
	$task = $task.ToLower()

	if($projectConfig -eq $null){
		$yamlPackagePath = Get-PackagePath "YamlDotNet" $projectName
		Add-Type -Path "$yamlPackagePath\lib\netstandard1.3\yamldotnet.dll"
		$config = Resolve-Path ".\config.yml"
		$yaml = [IO.File]::ReadAllText($config).Replace("`t", "    ")
		$stringReader = new-object System.IO.StringReader([string]$yaml)
		$Deserializer = New-Object -TypeName YamlDotNet.Serialization.Deserializer -ArgumentList $null, $null, $false
		$projectConfig = $Deserializer.Deserialize([System.IO.TextReader]$stringReader)
	}
	
	$config = @{
		"clean" = "EmbeddedWebJob", "StandaloneWebJob", "App", "VsTest", "XUnit", "VsTestAndXUnit", "Package";
		"compile" = "EmbeddedWebJob", "StandaloneWebJob", "App", "VsTest", "XUnit", "VsTestAndXUnit", "Package";
		"test" = "VsTest", "XUnit", "VsTestAndXUnit";
		"pack" = "StandaloneWebJob", "Package", "App";
		"push" = "StandaloneWebJob", "Package", "App";
		"release" = "StandaloneWebJob", "App";
		"deploy" = "StandaloneWebJob", "App";
	}
	$projectTypes = $config[$task]

    return $projectConfig.Keys | 
        Where { 
			($projectTypes -contains $projectConfig[$_]["Type"] -and `
			($projectConfig[$_]["Exclude"] -eq $null -or $projectConfig[$_]["Exclude"].ToLower().IndexOf($task) -eq -1) -or `
			 ($projectConfig[$_]["Include"] -ne $null -and $projectConfig[$_]["Include"].ToLower().IndexOf($task) -ne -1))
		} | 
        ForEach-Object { 
            @{
                "Name" = $_;
                "Type" = $projectConfig[$_]["Type"];
                "Config" = $projectConfig[$_]["Config"];
            }}
}

#endregion

#region "Clean"

function Clean-Folder($folder){
	"Cleaning $folder"
	Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}

#endregion

#region Compile

function Compile-Project($projectName) {
	use "15.0" MsBuild
	$projectFile = "$projectName\$projectName.csproj"
	$isWebProject = (((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path $projectFile) -ne $null) -and ((Select-String -pattern "<OutputType>WinExe</OutputType>" -path $projectFile) -eq $null))
	$isWinProject = (((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path $projectFile) -eq $null) -and ((Select-String -pattern "<OutputType>WinExe</OutputType>" -path $projectFile) -ne $null))
	$isExeProject = (((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path $projectFile) -eq $null) -and ((Select-String -pattern "<OutputType>Exe</OutputType>" -path $projectFile) -ne $null))
	
	if ($isWebProject) {
		Write-Host "Compiling $projectName to $artifactsPath"
		exec { MSBuild $projectFile /p:Configuration=$config /nologo /p:DebugType=None /p:Platform=AnyCpu /p:WebProjectOutputDir=..\$artifactsPath\$projectName /p:OutDir=$artifactsPath\bin /verbosity:quiet }
	}
	elseif ($isWinProject -or $isExeProject) {
		Write-Host "Compiling $projectName to $artifactsPath"
		exec { MSBuild $projectFile /p:Configuration=$config /nologo /p:DebugType=None /p:Platform=AnyCpu /p:OutDir=..\$artifactsPath\$projectName /verbosity:quiet /p:Disable_CopyWebApplication=True }
	}
	else{
		Write-Host "Compiling $projectName"
		exec { MSBuild $projectFile /p:Configuration=$config /nologo /p:Platform=AnyCpu /verbosity:quiet }
	}
}

#endregion

#region Push and Pack
$versions = @{}
function Get-Version($projectName) {
	if(!$versions.ContainsKey($projectName)){

		$line = Get-Content "$projectName\Properties\AssemblyInfo.cs" | Where { $_.Contains("AssemblyVersion") }
		if (!$line) {
			$line = Get-Content "$projectName\..\SharedAssemblyInfo.cs" | Where { $_.Contains("AssemblyVersion") }
			if (!$line) {
				throw "Couldn't find an AssemblyVersion attribute"
			}
		}
		$version = $line.Split('"')[1]
		$branch = Get-CurrentBranch
		$isGeneralRelease = Is-GeneralRelease $branch
		$isLocalBuild = Is-LocalBuild

		if($isLocalBuild -or !$isGeneralRelease){
			$version = "$($version.Replace("*", 0))-$(Get-PrereleaseNumber $branch)"
		} else{
			$version = $version.Replace("*", $env:APPVEYOR_BUILD_NUMBER)
		}
		$versions.Add($projectName, $version)
	}

	return $versions[$projectName]
}

function Get-CurrentBranch{
	if([String]::IsNullOrEmpty($env:APPVEYOR_REPO_BRANCH)){
		$branch = git branch | Where {$_ -match "^\*(.*)"} | Select-Object -First 1
	} else{
		$branch = $env:APPVEYOR_REPO_BRANCH
	}
	return $branch
}

function Is-GeneralRelease($branch){
	return ($branch -eq "develop" -or $branch -eq "master")
}

function Is-LocalBuild(){
	return [String]::IsNullOrEmpty($env:APPVEYOR_REPO_BRANCH)
}

function Get-PrereleaseNumber($branch){
	$branch = $branch.Replace("* ", "")
    if($branch.IndexOf("/") -ne -1){
        $prefix = $branch.Substring(0, $branch.IndexOf("/") + 1)
    }else{
        $prefix = $branch
    }

    $prefix = $prefix.Substring(0, [System.Math]::Min(7, $prefix.Length))
	return $prefix + "-" + $prereleaseDate -Replace "[^a-zA-Z0-9-]", ""
}

function Pack-Project($projectName){
	$version = Get-Version $projectName
	Write-Host "Packing $projectName $version to $artifactsPath"
	exec { & NuGet pack $projectName\$projectName.csproj -Build -Properties Configuration=$config -OutputDirectory $artifactsPath -Version $version -IncludeReferencedProjects -NonInteractive }
}

function Push-Package($package, $nugetPackageSource, $nugetPackageSourceApiKey, $ignoreNugetPushErrors) {
	$package = $package -replace "\.", "\."
	$package = @(Get-ChildItem $artifactsPath\*.nupkg) | Where-Object {$_.Name -match "$package\.\d*\.\d*\.\d*.*\.nupkg"}
	try {
		if (![string]::IsNullOrEmpty($nugetPackageSourceApiKey) -and $nugetPackageSourceApiKey -ne "LoadFromNuGetConfig") {
			$out = NuGet push $package -Source $nugetPackageSource -ApiKey $nugetPackageSourceApiKey 2>&1
		}
		else {
			$out = NuGet push $package -Source $nugetPackageSource 2>&1
		}
		Write-Host $out
	}
	catch {
		$errorMessage = $_
		$ignoreNugetPushErrors.Split(";") | foreach {
			if ($([String]$errorMessage).Contains($_)) {
				$isNugetPushError = $true
			}
		}
		if (!$isNugetPushError) {
			throw
		}
		else {
			Write-Host "WARNING: $errorMessage"
		}
	}
}

#endregion