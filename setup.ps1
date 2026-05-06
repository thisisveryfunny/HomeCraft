param(
	[switch]$Production,
	[switch]$SkipMinecraft,
	[string]$MinecraftDir = "C:\minecraft"
)

$ErrorActionPreference = "Stop"

$MinecraftJarUrl = "https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
$PanelPort = 3000

function Test-Command($Name) {
	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-NodeVersion {
	$parts = (& node -v).TrimStart("v").Split(".")
	$major = [int]$parts[0]
	$minor = [int]$parts[1]
	return ($major -eq 20 -and $minor -ge 19) -or ($major -eq 22 -and $minor -ge 12) -or ($major -ge 24)
}

function Get-JavaMajorVersion {
	$line = (& java -version 2>&1 | Select-Object -First 1)
	if ($line -match '"([^"]+)"') {
		$parts = $Matches[1].Split(".")
		if ($parts[0] -eq "1") {
			return [int]$parts[1]
		}
		return [int]$parts[0]
	}
	return 0
}

Write-Host "HomeCraft Windows Setup"
Write-Host "======================="

Write-Host "[1/6] Checking requirements..."
if (-not (Test-Command "node")) {
	throw "Node.js 20.19+, 22.12+, or 24+ is required. Install it from https://nodejs.org/ and rerun this script."
}

if (-not (Test-NodeVersion)) {
	throw "Node.js 20.19+, 22.12+, or 24+ is required. Found $(& node -v)."
}
Write-Host "  Node.js $(& node -v)"

if (-not (Test-Command "npm")) {
	throw "npm is required."
}
Write-Host "  npm $(& npm -v)"

if (-not (Test-Command "java")) {
	throw "Java 17+ is required. Install Temurin/OpenJDK 17+ and make sure java is on PATH."
}

if ((Get-JavaMajorVersion) -lt 17) {
	throw "Java 17+ is required. Found $(& java -version 2>&1 | Select-Object -First 1)."
}
Write-Host "  Java $(& java -version 2>&1 | Select-Object -First 1)"

Write-Host "[2/6] Installing dependencies..."
npm install

Write-Host "[3/6] Saving HomeCraft config..."
$resolvedMinecraftDir = [System.IO.Path]::GetFullPath($MinecraftDir)
New-Item -ItemType Directory -Force -Path ".homecraft" | Out-Null
@{
	minecraftDir = $resolvedMinecraftDir
} | ConvertTo-Json | Set-Content -Encoding UTF8 -Path ".homecraft\config.json"

Write-Host "[4/6] Preparing Minecraft server folder..."
New-Item -ItemType Directory -Force -Path $resolvedMinecraftDir | Out-Null

if (-not $SkipMinecraft) {
	$jarPath = Join-Path $resolvedMinecraftDir "server.jar"
	if (-not (Test-Path $jarPath)) {
		Write-Host "  Downloading server.jar..."
		Invoke-WebRequest -Uri $MinecraftJarUrl -OutFile $jarPath
	} else {
		Write-Host "  server.jar already exists"
	}

	$eulaPath = Join-Path $resolvedMinecraftDir "eula.txt"
	if (-not (Test-Path $eulaPath)) {
		"eula=true" | Set-Content -Encoding UTF8 -Path $eulaPath
	}

	$propertiesPath = Join-Path $resolvedMinecraftDir "server.properties"
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
		$filePath = Join-Path $resolvedMinecraftDir $jsonFile
		if (-not (Test-Path $filePath)) {
			"[]" | Set-Content -Encoding UTF8 -Path $filePath
		}
	}
} else {
	Write-Host "  Skipping Minecraft server setup"
}

if ($Production) {
	Write-Host "[5/6] Building for production..."
	npm run build
} else {
	Write-Host "[5/6] Skipping production build"
}

Write-Host "[6/6] Setup complete"
Write-Host ""
if ($Production) {
	Write-Host "Start the panel:"
	Write-Host "  `$env:PORT=$PanelPort; node build"
	Write-Host "Access it at http://localhost:$PanelPort"
} else {
	Write-Host "Start the development server:"
	Write-Host "  npm run dev"
	Write-Host "Access it at http://localhost:5173"
}
Write-Host ""
Write-Host "Minecraft server folder: $resolvedMinecraftDir"
