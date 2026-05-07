param(
	[string]$Configuration = "Release",
	[string]$InnoCompiler = "C:\Users\meterpeter\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = "Stop"

$InstallerRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $InstallerRoot
$LauncherProject = Join-Path $InstallerRoot "launcher\HomeCraft.Launcher\HomeCraft.Launcher.csproj"
$PublishDir = Join-Path $InstallerRoot "dist\launcher"
$InnoScript = Join-Path $InstallerRoot "inno\HomeCraftInstaller.iss"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
	throw ".NET SDK is required to publish the launcher. Install .NET 8 SDK or newer."
}

if (-not (Test-Path $InnoCompiler)) {
	throw "Inno Setup compiler was not found at '$InnoCompiler'. Install Inno Setup 6 or pass -InnoCompiler."
}

Remove-Item -Recurse -Force $PublishDir -ErrorAction SilentlyContinue
dotnet publish $LauncherProject `
	-c $Configuration `
	-r win-x64 `
	--self-contained true `
	-p:PublishSingleFile=true `
	-p:PublishTrimmed=false `
	-o $PublishDir

& $InnoCompiler $InnoScript

Write-Host ""
Write-Host "Installer output:"
Write-Host (Join-Path $RepoRoot "dist\HomeCraftSetup.exe")
