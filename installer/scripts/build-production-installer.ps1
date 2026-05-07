param(
	[string]$Configuration = "Release",
	[string]$InnoCompiler = "",
	[string]$NodeArchive = "",
	[string]$NodeSource = "",
	[string]$JavaArchive = "",
	[string]$JavaSource = "",
	[string]$SignTool = "",
	[string]$SignCertificateThumbprint = "",
	[string]$SignCertificatePath = "",
	[string]$SignCertificatePassword = "",
	[string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$NodeVersion = "22.12.0"
$NodeZipUrl = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-win-x64.zip"
$JavaZipUrl = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse"

$InstallerRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $InstallerRoot
$LauncherProject = Join-Path $InstallerRoot "launcher\HomeCraft.Launcher\HomeCraft.Launcher.csproj"
$PackageDir = Join-Path $InstallerRoot "dist\package"
$PackageAppDir = Join-Path $PackageDir "app"
$PackageToolsDir = Join-Path $PackageDir "tools"
$PackageInstallerDir = Join-Path $PackageDir "installer"
$BuildToolsDir = Join-Path $InstallerRoot "dist\build-tools"
$BuildWorkDir = Join-Path $InstallerRoot "dist\build-work"
$BuildSourceDir = Join-Path $BuildWorkDir "source"
$InnoScript = Join-Path $InstallerRoot "inno\HomeCraftInstaller.iss"
$OutputInstaller = Join-Path $RepoRoot "dist\HomeCraftSetup.exe"

function Resolve-CommandPath($Names, $ErrorMessage) {
	foreach ($name in $Names) {
		$command = Get-Command $name -ErrorAction SilentlyContinue
		if ($command) {
			return $command.Source
		}
	}

	throw $ErrorMessage
}

function Resolve-InnoCompiler {
	if ($InnoCompiler -and (Test-Path $InnoCompiler)) {
		return $InnoCompiler
	}

	$candidates = @(
		"${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
		"$env:ProgramFiles\Inno Setup 6\ISCC.exe",
		"$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
	)

	foreach ($candidate in $candidates) {
		if ($candidate -and (Test-Path $candidate)) {
			return $candidate
		}
	}

	throw "Inno Setup compiler was not found. Install Inno Setup 6 or pass -InnoCompiler."
}

function Invoke-Checked($FilePath, $Arguments, $WorkingDirectory = $RepoRoot) {
	Write-Host "> $FilePath $Arguments"
	$process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -Wait -PassThru -NoNewWindow
	if ($process.ExitCode -ne 0) {
		throw "Command failed with exit code $($process.ExitCode): $FilePath $Arguments"
	}
}

function Copy-Directory($Source, $Destination) {
	if (-not (Test-Path $Source)) {
		throw "Required source folder was not found: $Source"
	}

	New-Item -ItemType Directory -Force -Path $Destination | Out-Null
	Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Copy-SourceForBuild($Destination) {
	if (Test-Path $Destination) {
		Remove-Item -Recurse -Force $Destination
	}

	New-Item -ItemType Directory -Force -Path $Destination | Out-Null

	$requiredItems = @(
		"package.json",
		"package-lock.json",
		"svelte.config.js",
		"tsconfig.json",
		"vite.config.ts",
		"src",
		"static"
	)

	foreach ($item in $requiredItems) {
		$source = Join-Path $RepoRoot $item
		if (-not (Test-Path $source)) {
			throw "Required source item was not found: $source"
		}

		Copy-Item -Path $source -Destination (Join-Path $Destination $item) -Recurse -Force
	}
}

function Download-File($Url, $OutFile) {
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
	Write-Host "Downloading $Url"
	Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-ArchiveRoot($ArchivePath, $Destination) {
	$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("homecraft_extract_" + [System.Guid]::NewGuid().ToString("N"))
	New-Item -ItemType Directory -Force -Path $tmp | Out-Null

	try {
		Expand-Archive -Path $ArchivePath -DestinationPath $tmp -Force
		$root = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
		if (-not $root) {
			throw "Archive did not contain a root folder: $ArchivePath"
		}

		if (Test-Path $Destination) {
			Remove-Item -Recurse -Force $Destination
		}

		New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
		Move-Item -Path $root.FullName -Destination $Destination
	}
	finally {
		Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
	}
}

function Prepare-Node($Destination) {
	if ($NodeSource) {
		Copy-Directory $NodeSource $Destination
	} else {
		$archive = $NodeArchive
		if (-not $archive) {
			$archive = Join-Path $InstallerRoot "vendor\node-v$NodeVersion-win-x64.zip"
			if (-not (Test-Path $archive)) {
				Download-File $NodeZipUrl $archive
			}
		}
		Expand-ArchiveRoot $archive $Destination
	}

	if (-not (Test-Path (Join-Path $Destination "node.exe"))) {
		throw "Staged Node.js is missing node.exe: $Destination"
	}
}

function Resolve-Npm {
	$command = Get-Command @("npm.cmd", "npm.exe", "npm") -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($command) {
		return $command.Source
	}

	Write-Warning "npm was not found on PATH. Downloading portable Node.js for the build."
	$buildNodeDir = Join-Path $BuildToolsDir "node"
	Prepare-Node $buildNodeDir

	$npmPath = Join-Path $buildNodeDir "npm.cmd"
	if (-not (Test-Path $npmPath)) {
		throw "Portable Node.js was staged, but npm.cmd was not found: $npmPath"
	}

	return $npmPath
}

function Prepare-Java($Destination) {
	if ($JavaSource) {
		Copy-Directory $JavaSource $Destination
	} else {
		$archive = $JavaArchive
		if (-not $archive) {
			$archive = Join-Path $InstallerRoot "vendor\temurin-jre-21-win-x64.zip"
			if (-not (Test-Path $archive)) {
				Download-File $JavaZipUrl $archive
			}
		}
		Expand-ArchiveRoot $archive $Destination
	}

	$javaExe = Get-ChildItem -Path $Destination -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
	if (-not $javaExe) {
		throw "Staged Java is missing java.exe: $Destination"
	}
}

function Invoke-OptionalSigning {
	if (-not $SignCertificateThumbprint -and -not $SignCertificatePath) {
		Write-Warning "Installer was not signed. Windows SmartScreen may warn users."
		return
	}

	$tool = $SignTool
	if (-not $tool) {
		$tool = "signtool.exe"
	}

	if ($SignCertificateThumbprint) {
		$args = @("sign", "/fd", "SHA256", "/tr", $TimestampUrl, "/td", "SHA256", "/sha1", $SignCertificateThumbprint, $OutputInstaller)
	} else {
		$args = @("sign", "/fd", "SHA256", "/tr", $TimestampUrl, "/td", "SHA256", "/f", $SignCertificatePath)
		if ($SignCertificatePassword) {
			$args += @("/p", $SignCertificatePassword)
		}
		$args += $OutputInstaller
	}

	Invoke-Checked $tool $args $RepoRoot
}

$dotnet = Resolve-CommandPath @("dotnet.exe", "dotnet") ".NET SDK is required to publish the launcher. Install .NET 8 SDK or newer."
$npm = Resolve-Npm
$resolvedInnoCompiler = Resolve-InnoCompiler

Write-Host "Cleaning installer package staging..."
Remove-Item -Recurse -Force $PackageDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $BuildWorkDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $PackageAppDir, $PackageToolsDir, $PackageInstallerDir | Out-Null
New-Item -ItemType Directory -Force -Path $BuildWorkDir | Out-Null

Write-Host "Creating clean build source copy..."
Copy-SourceForBuild $BuildSourceDir

Write-Host "Building HomeCraft app locally..."
Invoke-Checked $npm @("ci") $BuildSourceDir
Invoke-Checked $npm @("run", "build") $BuildSourceDir

Write-Host "Staging app payload..."
Copy-Directory (Join-Path $BuildSourceDir "build") (Join-Path $PackageAppDir "build")
Copy-Item -Path (Join-Path $BuildSourceDir "package.json") -Destination $PackageAppDir -Force
Copy-Item -Path (Join-Path $BuildSourceDir "package-lock.json") -Destination $PackageAppDir -Force
Invoke-Checked $npm @("ci", "--omit=dev", "--no-audit", "--fund=false") $PackageAppDir

Write-Host "Staging portable Node.js..."
Prepare-Node (Join-Path $PackageToolsDir "node")

Write-Host "Staging portable Java..."
Prepare-Java (Join-Path $PackageToolsDir "java")

Write-Host "Publishing launcher..."
$LauncherPublishDir = Join-Path $InstallerRoot "dist\launcher"
Remove-Item -Recurse -Force $LauncherPublishDir -ErrorAction SilentlyContinue
Invoke-Checked $dotnet @(
	"publish",
	$LauncherProject,
	"-c", $Configuration,
	"-r", "win-x64",
	"--self-contained", "true",
	"-p:PublishSingleFile=true",
	"-p:PublishTrimmed=false",
	"-o", $LauncherPublishDir
) $RepoRoot
Copy-Item -Path (Join-Path $LauncherPublishDir "HomeCraft.exe") -Destination (Join-Path $PackageDir "HomeCraft.exe") -Force

Copy-Item -Path (Join-Path $InstallerRoot "scripts\bootstrap-homecraft.ps1") -Destination $PackageInstallerDir -Force

Write-Host "Validating staged payload..."
$requiredPaths = @(
	(Join-Path $PackageDir "HomeCraft.exe"),
	(Join-Path $PackageAppDir "build"),
	(Join-Path $PackageAppDir "node_modules"),
	(Join-Path $PackageToolsDir "node\node.exe"),
	(Join-Path $PackageInstallerDir "bootstrap-homecraft.ps1")
)

foreach ($path in $requiredPaths) {
	if (-not (Test-Path $path)) {
		throw "Required staged path is missing: $path"
	}
}

$stagedJava = Get-ChildItem -Path (Join-Path $PackageToolsDir "java") -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $stagedJava) {
	throw "Required staged Java executable is missing."
}

Write-Host "Staged package root: $PackageDir"
Write-Host "Staged app folder: $PackageAppDir"
Write-Host "Staged app build: $(Join-Path $PackageAppDir 'build')"
Write-Host "Staged Node: $(Join-Path $PackageToolsDir 'node\node.exe')"
Write-Host "Staged Java: $($stagedJava.FullName)"

Write-Host "Compiling installer..."
Remove-Item -Force $OutputInstaller -ErrorAction SilentlyContinue
& $resolvedInnoCompiler "/DPackageRoot=$PackageDir" "/DOutputRoot=$(Join-Path $RepoRoot 'dist')" $InnoScript
if ($LASTEXITCODE -ne 0) {
	throw "Inno Setup failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path $OutputInstaller)) {
	throw "Inno Setup completed but did not produce the expected installer: $OutputInstaller"
}

Invoke-OptionalSigning

Write-Host ""
Write-Host "Production installer output:"
Write-Host $OutputInstaller
