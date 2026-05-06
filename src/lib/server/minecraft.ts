import { spawn, type ChildProcess } from 'child_process';
import { EventEmitter } from 'events';
import { getMinecraftDir } from './config';

const MC_JAR = 'server.jar';

class MinecraftServer extends EventEmitter {
	private process: ChildProcess | null = null;
	private logs: string[] = [];
	private maxLogs = 500;
	private onlinePlayers: Set<string> = new Set();
	private startTime: number | null = null;
	private playerListInterval: ReturnType<typeof setInterval> | null = null;

	constructor() {
		super();
		// Prevent unhandled error events from crashing the process
		this.on('error', () => {});
	}

	private startPlayerListPolling() {
		this.stopPlayerListPolling();
		// Poll player list every 10 seconds to keep it in sync
		this.playerListInterval = setInterval(() => {
			if (this.isRunning && this.process?.stdin) {
				this.process.stdin.write('list\n');
			}
		}, 10000);
	}

	private stopPlayerListPolling() {
		if (this.playerListInterval) {
			clearInterval(this.playerListInterval);
			this.playerListInterval = null;
		}
	}

	get isRunning(): boolean {
		return this.process !== null && !this.process.killed;
	}

	getLogs(): string[] {
		return [...this.logs];
	}

	getOnlinePlayers(): string[] {
		return [...this.onlinePlayers];
	}

	private stripAnsiCodes(str: string): string {
		// Remove ANSI escape codes (color codes like \x1b[93m)
		return str.replace(/\x1b\[[0-9;]*m/g, '');
	}

	private parsePlayerEvents(line: string) {
		// Strip ANSI color codes for reliable parsing
		const cleanLine = this.stripAnsiCodes(line);

		// Match patterns like "PlayerName joined the game"
		const joinMatch = cleanLine.match(/(\S+)\s+joined the game/);
		if (joinMatch) {
			this.onlinePlayers.add(joinMatch[1]);
			return;
		}

		// Match patterns like "PlayerName left the game"
		const leaveMatch = cleanLine.match(/(\S+)\s+left the game/);
		if (leaveMatch) {
			this.onlinePlayers.delete(leaveMatch[1]);
			return;
		}

		// Parse vanilla "list" command output: "There are X of a max of Y players online: player1, player2"
		const vanillaListMatch = cleanLine.match(/There are (\d+) of a max of \d+ players online:(.*)/);
		if (vanillaListMatch) {
			this.onlinePlayers.clear();
			const playerList = vanillaListMatch[2].trim();
			if (playerList) {
				playerList.split(',').forEach(p => {
					const name = p.trim();
					if (name) this.onlinePlayers.add(name);
				});
			}
			return;
		}

		// Parse Essentials "list" command output: "There are X out of maximum Y players online."
		const essentialsListMatch = cleanLine.match(/There are (\d+) out of maximum \d+ players online/);
		if (essentialsListMatch) {
			const count = parseInt(essentialsListMatch[1], 10);
			if (count === 0) {
				this.onlinePlayers.clear();
			}
			// If count > 0, players are listed on following lines, parsed by join events
		}
	}

	start(): { success: boolean; message: string } {
		if (this.isRunning) {
			return { success: false, message: 'Server is already running' };
		}

		try {
			this.logs = [];
			this.onlinePlayers.clear();
			this.startTime = Date.now();
			const minecraftDir = getMinecraftDir();
			this.process = spawn('java', ['-Xmx1024M', '-Xms512M', '-jar', MC_JAR, 'nogui'], {
				cwd: minecraftDir,
				stdio: ['pipe', 'pipe', 'pipe']
			});

			this.process.stdout?.on('data', (data) => {
				const lines = data.toString().split('\n').filter((l: string) => l.trim());
				lines.forEach((line: string) => {
					this.logs.push(line);
					if (this.logs.length > this.maxLogs) {
						this.logs.shift();
					}
					this.parsePlayerEvents(line);
					this.emit('log', line);
				});
			});

			this.process.stderr?.on('data', (data) => {
				const lines = data.toString().split('\n').filter((l: string) => l.trim());
				lines.forEach((line: string) => {
					this.logs.push(`[ERROR] ${line}`);
					if (this.logs.length > this.maxLogs) {
						this.logs.shift();
					}
					this.emit('log', `[ERROR] ${line}`);
				});
			});

			this.process.on('close', (code) => {
				this.stopPlayerListPolling();
				this.logs.push(`[SYSTEM] Server stopped with code ${code}`);
				this.process = null;
				this.onlinePlayers.clear();
				this.startTime = null;
				this.emit('stopped', code);
			});

			this.process.on('error', (err) => {
				this.stopPlayerListPolling();
				this.logs.push(`[SYSTEM] Error: ${err.message}`);
				this.process = null;
				this.onlinePlayers.clear();
				this.startTime = null;
				// Don't re-emit, just log it - prevents crash
			});

			// Start polling player list after server starts
			this.startPlayerListPolling();

			return { success: true, message: 'Server starting...' };
		} catch (error) {
			this.process = null;
			this.startTime = null;
			return { success: false, message: `Failed to start: ${error}` };
		}
	}

	stop(): { success: boolean; message: string } {
		if (!this.isRunning || !this.process) {
			return { success: false, message: 'Server is not running' };
		}

		try {
			this.sendCommand('stop');
			setTimeout(() => {
				if (this.process && !this.process.killed) {
					this.process.kill('SIGTERM');
				}
			}, 10000);
			return { success: true, message: 'Server stopping...' };
		} catch (error) {
			return { success: false, message: `Failed to stop: ${error}` };
		}
	}

	sendCommand(command: string): { success: boolean; message: string } {
		if (!this.isRunning || !this.process?.stdin) {
			return { success: false, message: 'Server is not running' };
		}

		try {
			this.process.stdin.write(`${command}\n`);
			this.logs.push(`> ${command}`);
			return { success: true, message: 'Command sent' };
		} catch (error) {
			return { success: false, message: `Failed to send command: ${error}` };
		}
	}

	getStatus(): { running: boolean; uptime: number | null; playerCount: number; players: string[] } {
		return {
			running: this.isRunning,
			uptime: this.startTime ? Math.floor((Date.now() - this.startTime) / 1000) : null,
			playerCount: this.onlinePlayers.size,
			players: this.getOnlinePlayers()
		};
	}
}

export const mcServer = new MinecraftServer();
