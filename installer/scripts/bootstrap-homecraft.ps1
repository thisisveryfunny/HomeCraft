param(
	[Parameter(Mandatory = $true)]
	[string]$InstallDir,

	[Parameter(Mandatory = $true)]
	[ValidateSet("Fresh", "Existing")]
	[string]$MinecraftMode,

	[Parameter(Mandatory = $true)]
	[string]$MinecraftDir,

	[bool]$AcceptMinecraftEula = $false,

	[string]$RepoUrl = "https://github.com/thisisveryfunny/HomeCraft.git",
	[string]$RepoBranch = "",
	[int]$PanelPort = 3000
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$NodeVersion = "22.12.0"
$NodeZipUrl = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-win-x64.zip"
$JavaZipUrl = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse"
$MinecraftJarUrl = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$MinecraftDir = [System.IO.Path]::GetFullPath($MinecraftDir)
$ToolsDir = Join-Path $InstallDir "tools"
$AppDir = Join-Path $InstallDir "app"
$LogDir = Join-Path $InstallDir "logs"
$LogFile = Join-Path $LogDir "install.log"

New-Item -ItemType Directory -Force -Path $InstallDir, $ToolsDir, $LogDir | Out-Null
Start-Transcript -Path $LogFile -Append | Out-Null

function Write-Step($Message) {
	Write-Host ""
	Write-Host "==> $Message"
}

function Invoke-Download($Url, $OutFile) {
	Write-Host "Downloading $Url"
	Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-ZipTool($Url, $ArchiveName, $Destination, $FlattenTo = $null) {
	New-Item -ItemType Directory -Force -Path $Destination | Out-Null
	$archivePath = Join-Path $ToolsDir $ArchiveName
	Invoke-Download $Url $archivePath
	$tmpName = "_extract_$([System.IO.Path]::GetFileNameWithoutExtension($ArchiveName))"
	$tmp = Join-Path $ToolsDir $tmpName
	if (Test-Path $tmp) {
		Remove-Item $tmp -Recurse -Force
	}
	New-Item -ItemType Directory -Force -Path $tmp | Out-Null
	Expand-Archive -Path $archivePath -DestinationPath $tmp -Force
	Remove-Item $archivePath -Force

	if ($FlattenTo) {
		if (Test-Path $FlattenTo) {
			Remove-Item $FlattenTo -Recurse -Force
		}
		$root = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
		if (-not $root) {
			throw "Could not find extracted tool root in $tmp"
		}
		Move-Item -Path $root.FullName -Destination $FlattenTo
		Remove-Item $tmp -Recurse -Force
	}
}

function Get-GitPortableAssetUrl {
	$release = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -Headers @{ "User-Agent" = "HomeCraftInstaller" }
	$asset = $release.assets |
		Where-Object { $_.name -match '^PortableGit-.*64-bit\.7z\.exe$' } |
		Select-Object -First 1

	if (-not $asset) {
		throw "Could not find a 64-bit PortableGit release asset."
	}

	return $asset.browser_download_url
}

function Ensure-Node {
	$nodeExe = Join-Path $ToolsDir "node\node.exe"
	if (Test-Path $nodeExe) {
		return $nodeExe
	}

	Write-Step "Installing portable Node.js"
	Expand-ZipTool $NodeZipUrl "node.zip" $ToolsDir (Join-Path $ToolsDir "node")
	return $nodeExe
}

function Ensure-Java {
	$javaExe = Get-ChildItem -Path $ToolsDir -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($javaExe) {
		return $javaExe.FullName
	}

	Write-Step "Installing portable Java"
	Expand-ZipTool $JavaZipUrl "java.zip" $ToolsDir (Join-Path $ToolsDir "java")
	$javaExe = Get-ChildItem -Path (Join-Path $ToolsDir "java") -Filter "java.exe" -Recurse | Select-Object -First 1
	if (-not $javaExe) {
		throw "Portable Java extraction did not produce java.exe"
	}
	return $javaExe.FullName
}

function Ensure-Git {
	$gitExe = Join-Path $ToolsDir "git\cmd\git.exe"
	if (Test-Path $gitExe) {
		return $gitExe
	}

	Write-Step "Installing portable Git"
	$gitInstaller = Join-Path $ToolsDir "portable-git.7z.exe"
	Invoke-Download (Get-GitPortableAssetUrl) $gitInstaller
	$gitDir = Join-Path $ToolsDir "git"
	if (Test-Path $gitDir) {
		Remove-Item $gitDir -Recurse -Force
	}
	New-Item -ItemType Directory -Force -Path $gitDir | Out-Null
	Start-Process -FilePath $gitInstaller -ArgumentList "-o`"$gitDir`"", "-y" -Wait -NoNewWindow
	Remove-Item $gitInstaller -Force

	if (-not (Test-Path $gitExe)) {
		throw "Portable Git extraction did not produce git.exe"
	}
	return $gitExe
}

function Add-ToolPath($Path) {
	if ((Test-Path $Path) -and ($env:Path -notlike "*$Path*")) {
		$env:Path = "$Path;$env:Path"
	}
}

function Invoke-Checked($FilePath, $Arguments, $WorkingDirectory = $InstallDir) {
	Write-Host "> $FilePath $Arguments"
	$process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -Wait -PassThru -NoNewWindow
	if ($process.ExitCode -ne 0) {
		throw "Command failed with exit code $($process.ExitCode): $FilePath $Arguments"
	}
}

try {
	Write-Step "Preparing portable dependencies"
	$nodeExe = Ensure-Node
	$javaExe = Ensure-Java
	$gitExe = Ensure-Git

	Add-ToolPath (Split-Path $nodeExe -Parent)
	Add-ToolPath (Split-Path $javaExe -Parent)
	Add-ToolPath (Join-Path $ToolsDir "git\cmd")
	Add-ToolPath (Join-Path $ToolsDir "git\bin")

	Write-Step "Installing HomeCraft app"
	if (Test-Path (Join-Path $AppDir ".git")) {
		Invoke-Checked $gitExe "pull --ff-only" $AppDir
	} elseif (Test-Path $AppDir) {
		throw "The app folder already exists but is not a Git checkout: $AppDir"
	} else {
		$cloneArgs = @("clone", "--depth", "1")
		if ($RepoBranch.Trim()) {
			$cloneArgs += @("--branch", $RepoBranch.Trim())
		}
		$cloneArgs += @($RepoUrl, $AppDir)
		Invoke-Checked $gitExe $cloneArgs $InstallDir
	}

	Write-Step "Configuring Minecraft server folder"
	New-Item -ItemType Directory -Force -Path $MinecraftDir | Out-Null

	if ($MinecraftMode -eq "Fresh") {
		if (-not $AcceptMinecraftEula) {
			throw "Minecraft EULA acceptance is required for a fresh server install."
		}

		$jarPath = Join-Path $MinecraftDir "server.jar"
		if (-not (Test-Path $jarPath)) {
			Invoke-Download $MinecraftJarUrl $jarPath
		}

		Set-Content -Encoding UTF8 -Path (Join-Path $MinecraftDir "eula.txt") -Value "eula=true"

		$propertiesPath = Join-Path $MinecraftDir "server.properties"
		if (-not (Test-Path $propertiesPath)) {
@"
#Minecraft server properties
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=\u00A7aHomeCraft Server\u00A7r - Welcome!
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=false
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
"@ | Set-Content -Encoding UTF8 -Path $propertiesPath
		}

		foreach ($jsonFile in @("whitelist.json", "ops.json", "banned-players.json")) {
			$filePath = Join-Path $MinecraftDir $jsonFile
			if (-not (Test-Path $filePath)) {
				Set-Content -Encoding UTF8 -Path $filePath -Value "[]"
			}
		}
	} elseif (-not (Test-Path (Join-Path $MinecraftDir "server.jar"))) {
		throw "Existing server folder must contain server.jar: $MinecraftDir"
	}

	Write-Step "Writing HomeCraft config"
	$configDir = Join-Path $AppDir ".homecraft"
	New-Item -ItemType Directory -Force -Path $configDir | Out-Null
	@{
		minecraftDir = $MinecraftDir
	} | ConvertTo-Json | Set-Content -Encoding UTF8 -Path (Join-Path $configDir "config.json")

	Write-Step "Installing Node dependencies"
	Invoke-Checked (Join-Path (Split-Path $nodeExe -Parent) "npm.cmd") "install" $AppDir

	Write-Step "Building HomeCraft"
	$env:NODE_ENV = "production"
	$env:PORT = "$PanelPort"
	Invoke-Checked (Join-Path (Split-Path $nodeExe -Parent) "npm.cmd") "run build" $AppDir

	Write-Step "Installation complete"
	Write-Host "HomeCraft app: $AppDir"
	Write-Host "Minecraft server: $MinecraftDir"
	Write-Host "Launcher: $(Join-Path $InstallDir 'HomeCraft.exe')"
}
finally {
	Stop-Transcript | Out-Null
}
