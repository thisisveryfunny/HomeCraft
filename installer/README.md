# HomeCraft Windows Installer

This folder contains the Windows installer tooling for HomeCraft.

## What it builds

- `HomeCraftSetup.exe` with Inno Setup.
- A self-contained C# console launcher named `HomeCraft.exe`.
- A PowerShell bootstrapper that installs portable tools, clones HomeCraft, prepares Minecraft, and builds the SvelteKit app.

The installed layout is:

```text
%LOCALAPPDATA%\Programs\HomeCraft\
  HomeCraft.exe
  installer\bootstrap-homecraft.ps1
  tools\
    node\
    java\
    git\
  app\
    .git\
    build\
    .homecraft\config.json
```

## Build requirements

- Windows x64
- .NET 8 SDK or newer
- Inno Setup 6

## Build command

From the repo root:

```powershell
.\installer\scripts\build-installer.ps1
```

The installer is written to:

```text
dist\HomeCraftSetup.exe
```

## Installer behavior

The installer asks for:

- HomeCraft install folder
- fresh vanilla Minecraft server or existing server folder
- Minecraft server folder
- Minecraft EULA acceptance when creating a fresh server

During installation, the bootstrapper:

- downloads portable Node.js 22.12.0
- downloads portable Java 21 JRE
- downloads latest Portable Git for Windows
- clones `https://github.com/thisisveryfunny/HomeCraft.git` into `app`
- runs `npm install`
- runs `npm run build`
- writes `app\.homecraft\config.json`

The Start Menu shortcut runs `HomeCraft.exe`, which starts the production SvelteKit server on:

```text
http://localhost:3000
```
