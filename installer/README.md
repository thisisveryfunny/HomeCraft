# HomeCraft Windows Installer

This folder contains the Windows production installer tooling for HomeCraft.

## What It Builds

- `HomeCraftSetup.exe` with Inno Setup.
- A self-contained C# console launcher named `HomeCraft.exe`.
- A self-contained install payload with built HomeCraft app files, production `node_modules`, portable Node.js, and portable Java.

The installed layout is:

```text
%LOCALAPPDATA%\Programs\HomeCraft\
  HomeCraft.exe
  installer\bootstrap-homecraft.ps1
  tools\
    node\
    java\
  app\
    build\
    node_modules\
    package.json
    package-lock.json
    .homecraft\config.json
```

## Build Requirements

- Windows x64
- .NET 8 SDK or newer
- Node.js/npm for building the package
- Inno Setup 6
- Internet access on the build machine unless `installer/vendor/` already contains the Node and Java archives

## Build Command

From the repo root:

```powershell
.\installer\scripts\build-production-installer.ps1
```

The installer is written to:

```text
dist\HomeCraftSetup.exe
```

`build-installer.ps1` calls the same production build script for compatibility.

## Installer Behavior

The production installer does not clone GitHub, download dependencies, run npm, or build HomeCraft on the user's machine.

The installer asks for:

- HomeCraft install folder
- existing Minecraft server folder containing `server.jar`

The installer then writes:

```text
app\.homecraft\config.json
```

The Start Menu shortcut runs `HomeCraft.exe`, which starts the production SvelteKit server on:

```text
http://localhost:3000
```

## Optional Signing

To sign with a certificate thumbprint:

```powershell
.\installer\scripts\build-production-installer.ps1 -SignCertificateThumbprint "THUMBPRINT"
```

To sign with a `.pfx`:

```powershell
.\installer\scripts\build-production-installer.ps1 -SignCertificatePath "C:\certs\homecraft.pfx" -SignCertificatePassword "password"
```
