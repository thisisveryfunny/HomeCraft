import { spawn, type ChildProcess } from 'child_process';
import { EventEmitter } from 'events';

const MC_SERVER_DIR = '/minecraft';
const MC_JAR = 'server.jar';

class MinecraftServer extends EventEmitter {
	private process: ChildProcess | null = null;
	private logs: string[] = [];
	private maxLogs = 500;
	private onlinePlayers: Set<string> = new Set();
	private startTime: number | null = null;

	constructor() {
		super();
		// Prevent unhandled error events from crashing the process
		this.on('error', () => {});
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

	private parsePlayerEvents(line: string) {
		// Match patterns like "[Server thread/INFO]: PlayerName joined the game"
		const joinMatch = line.match(/\[Server thread\/INFO\]:\s*(\w+)\s+joined the game/);
		if (joinMatch) {
			this.onlinePlayers.add(joinMatch[1]);
			return;
		}

		// Match patterns like "[Server thread/INFO]: PlayerName left the game"
		const leaveMatch = line.match(/\[Server thread\/INFO\]:\s*(\w+)\s+left the game/);
		if (leaveMatch) {
			this.onlinePlayers.delete(leaveMatch[1]);
			return;
		}

		// Parse "list" command output: "There are X of a max of Y players online: player1, player2"
		const listMatch = line.match(/There are (\d+) of a max of \d+ players online:(.*)/);
		if (listMatch) {
			this.onlinePlayers.clear();
			const playerList = listMatch[2].trim();
			if (playerList) {
				playerList.split(',').forEach(p => {
					const name = p.trim();
					if (name) this.onlinePlayers.add(name);
				});
			}
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
			this.process = spawn('java', ['-Xmx1024M', '-Xms512M', '-jar', MC_JAR, 'nogui'], {
				cwd: MC_SERVER_DIR,
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
				this.logs.push(`[SYSTEM] Server stopped with code ${code}`);
				this.process = null;
				this.onlinePlayers.clear();
				this.startTime = null;
				this.emit('stopped', code);
			});

			this.process.on('error', (err) => {
				this.logs.push(`[SYSTEM] Error: ${err.message}`);
				this.process = null;
				this.onlinePlayers.clear();
				this.startTime = null;
				// Don't re-emit, just log it - prevents crash
			});

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
