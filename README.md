# HomeCraft

A self-hosted Minecraft server admin panel built with SvelteKit. Manage a local Minecraft server from a private web interface.

## Features

- Dashboard with server status, uptime, online players, and recent logs
- File manager for browsing, editing, creating, deleting, and uploading server files
- Console for server logs and command execution
- Player management for whitelist, operators, and bans
- Server properties editor with common settings and MOTD tools
- Server icon upload with automatic 64x64 PNG conversion
- Configurable Minecraft server folder for Linux, macOS, and Windows

## Requirements

- Node.js 20.19+, 22.12+, or 24+
- npm
- Java 17+ on `PATH`
- A Minecraft server folder containing `server.jar`

This panel is designed for local/private use only. It has no authentication, so do not expose it to the public internet without adding proper access control.

## Windows Quick Start

Run PowerShell from the HomeCraft project folder:

```powershell
.\setup.ps1
npm run dev
```

Open:

```text
http://localhost:5173
```

By default, `setup.ps1` prepares `C:\minecraft`. To use another folder:

```powershell
.\setup.ps1 -MinecraftDir "D:\Servers\Minecraft"
npm run dev
```

For a production build:

```powershell
.\setup.ps1 -Production
$env:PORT=3000; node build
```

## Linux Quick Start

```bash
chmod +x setup.sh
./setup.sh
npm run dev
```

For a production build:

```bash
./setup.sh --production
sudo systemctl start homecraft
```

Manual production without systemd:

```bash
npm install
npm run build
PORT=3000 node build
```

## Minecraft Folder Configuration

HomeCraft stores local panel configuration in:

```text
.homecraft/config.json
```

That folder is gitignored because it contains machine-specific paths. The default Minecraft folder is:

- Windows: `C:\minecraft`
- Linux/macOS: `/minecraft`

You can change the folder from the web panel:

1. Open Settings.
2. Set "Minecraft Server Folder" to an absolute folder path.
3. Save the folder.

The configured folder must already exist. It should contain the Minecraft server files such as:

```text
server.jar
server.properties
whitelist.json
ops.json
banned-players.json
```

## Setup Script Options

Windows:

```powershell
.\setup.ps1 -Production
.\setup.ps1 -SkipMinecraft
.\setup.ps1 -SkipRequirementInstall
.\setup.ps1 -MinecraftDir "D:\Servers\Minecraft"
```

`setup.ps1` uses `winget` to install or upgrade Node.js LTS and Temurin Java when available. If `winget` is not installed, it downloads portable Node.js and Java into `.homecraft\tools` and uses them from the current PowerShell session. If a globally installed tool was just added and the script still cannot find it, restart PowerShell and rerun the script.

Linux:

```bash
./setup.sh --production
./setup.sh --skip-minecraft
./setup.sh --skip-service
```

## Windows Installer

The complete Windows installer tooling lives in `installer/`.

Build requirements:

- Windows x64
- .NET 8 SDK or newer
- Node.js/npm
- Inno Setup 6

Build the production installer from PowerShell:

```powershell
.\installer\scripts\build-production-installer.ps1
```

The output is:

```text
dist\HomeCraftSetup.exe
```

The production installer bundles the built HomeCraft app, production `node_modules`, portable Node.js, portable Java, and a `HomeCraft.exe` console launcher. It does not require Node.js, Java, Git, npm, or internet access on the user's machine. The installer asks for an existing Minecraft server folder containing `server.jar`.

## Development

```bash
npm install
npm run check
npm run build
```

## License

MIT
