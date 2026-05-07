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

$ProductionScript = Join-Path $PSScriptRoot "build-production-installer.ps1"

& $ProductionScript `
	-Configuration $Configuration `
	-InnoCompiler $InnoCompiler `
	-NodeArchive $NodeArchive `
	-NodeSource $NodeSource `
	-JavaArchive $JavaArchive `
	-JavaSource $JavaSource `
	-SignTool $SignTool `
	-SignCertificateThumbprint $SignCertificateThumbprint `
	-SignCertificatePath $SignCertificatePath `
	-SignCertificatePassword $SignCertificatePassword `
	-TimestampUrl $TimestampUrl
