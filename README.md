# ⛏️ HomeCraft

A modern, self-hosted Minecraft server admin panel built with SvelteKit. Manage your local Minecraft server through a sleek dark-themed web interface.

![HomeCraft Panel](https://img.shields.io/badge/Minecraft-Server%20Panel-green?style=for-the-badge&logo=minecraft)
![SvelteKit](https://img.shields.io/badge/SvelteKit-5-orange?style=for-the-badge&logo=svelte)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

## ✨ Features

- **🏠 Dashboard** - Server status, uptime, online players with avatars
- **📁 File Manager** - Browse, edit, create, delete, and upload server files
- **💻 Console** - Real-time server logs and command execution
- **👥 Player Management** - Whitelist, operators, and ban management in one place
- **⚙️ Settings** - Easy server.properties editor with toggles and dropdowns
- **📝 MOTD Editor** - Visual editor with color codes, formatting, and live preview
- **🖼️ Server Icon** - Upload custom server icon (auto-resized to 64x64)

## 🚀 Quick Start

### Automatic Setup

```bash
git clone https://github.com/yourusername/HomeCraft.git
cd HomeCraft
chmod +x setup.sh
./setup.sh
```

### Manual Setup

```bash
# Install dependencies
npm install

# Create Minecraft server directory
sudo mkdir -p /minecraft
sudo chown $USER:$USER /minecraft

# Download Minecraft server (optional - or use your own)
cd /minecraft
curl -O https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar
echo "eula=true" > eula.txt

# Build and run
cd /path/to/HomeCraft
npm run build
node build
```

## 📋 Requirements

- **Node.js** 18+ 
- **Java** 17+ (for Minecraft server)
- **Linux** (tested on Ubuntu/Debian)

## 🛠️ Configuration

The Minecraft server files are expected at `/minecraft`. You can change this by editing:
- `src/lib/server/minecraft.ts` - `MC_SERVER_DIR` constant
- API route files in `src/routes/api/`

### Server Memory

Default memory allocation is `-Xmx8G -Xms8G`. Modify in `src/lib/server/minecraft.ts`.

## 📦 Production Deployment

### Using the setup script
```bash
./setup.sh --production
```

### Using systemd (recommended)
```bash
# The setup script creates this automatically
sudo systemctl enable homecraft
sudo systemctl start homecraft
```

### Manual
```bash
npm run build
PORT=3000 node build
```

## 📸 Screenshots


## 🔒 Security Note

This panel is designed for **local/private use only**. There is no authentication system. Do not expose to the public internet without adding proper authentication.

## 📝 License

MIT License - feel free to use, modify, and distribute.

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

---
