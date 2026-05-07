param(
	[Parameter(Mandatory = $true)]
	[string]$InstallDir,

	[Parameter(Mandatory = $true)]
	[string]$MinecraftDir
)

$ErrorActionPreference = "Stop"

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$MinecraftDir = [System.IO.Path]::GetFullPath($MinecraftDir)
$AppDir = Join-Path $InstallDir "app"
$LogDir = Join-Path $InstallDir "logs"
$LogFile = Join-Path $LogDir "install.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Start-Transcript -Path $LogFile -Append | Out-Null

try {
	Write-Host "Configuring HomeCraft"
	Write-Host "Install folder: $InstallDir"
	Write-Host "Minecraft folder: $MinecraftDir"

	if (-not (Test-Path $AppDir)) {
		throw "HomeCraft app folder was not installed: $AppDir"
	}

	if (-not (Test-Path (Join-Path $AppDir "build"))) {
		throw "HomeCraft production build was not installed: $(Join-Path $AppDir 'build')"
	}

	if (-not (Test-Path $MinecraftDir)) {
		throw "Minecraft server folder does not exist: $MinecraftDir"
	}

	if (-not (Test-Path (Join-Path $MinecraftDir "server.jar"))) {
		throw "Minecraft server folder must contain server.jar: $MinecraftDir"
	}

	$configDir = Join-Path $AppDir ".homecraft"
	New-Item -ItemType Directory -Force -Path $configDir | Out-Null
	@{
		minecraftDir = $MinecraftDir
	} | ConvertTo-Json | Set-Content -Encoding UTF8 -Path (Join-Path $configDir "config.json")

	Write-Host "HomeCraft config written."
}
finally {
	Stop-Transcript | Out-Null
}
