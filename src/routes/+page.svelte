<script lang="ts">
	import { onMount } from 'svelte';

	interface ServerStatus {
		running: boolean;
		uptime: number | null;
		playerCount: number;
		players: string[];
	}

	let serverStatus = $state<ServerStatus>({ running: false, uptime: null, playerCount: 0, players: [] });
	let recentLogs = $state<string[]>([]);
	let loading = $state(true);
	let minecraftDir = $state('');
	let defaultMinecraftDir = $state('');
	let message = $state('');

	function formatUptime(seconds: number | null): string {
		if (seconds === null) return '--';
		const hours = Math.floor(seconds / 3600);
		const minutes = Math.floor((seconds % 3600) / 60);
		const secs = seconds % 60;
		if (hours > 0) return `${hours}h ${minutes}m`;
		if (minutes > 0) return `${minutes}m ${secs}s`;
		return `${secs}s`;
	}

	async function fetchStatus() {
		try {
			const res = await fetch('/api/server');
			const data = await res.json();
			serverStatus = data.status;
			recentLogs = data.logs.slice(-10);
		} catch (e) {
			console.error('Failed to fetch status:', e);
		} finally {
			loading = false;
		}
	}

	async function toggleServer() {
		const action = serverStatus.running ? 'stop' : 'start';
		loading = true;
		try {
			await fetch('/api/server', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action })
			});
			await new Promise((r) => setTimeout(r, 1000));
			await fetchStatus();
		} catch (e) {
			console.error('Failed to toggle server:', e);
		} finally {
			loading = false;
		}
	}

	async function fetchConfig() {
		try {
			const res = await fetch('/api/config');
			const data = await res.json();
			minecraftDir = data.config.minecraftDir;
			defaultMinecraftDir = data.defaults.minecraftDir;
		} catch (e) {
			message = `Error: ${e}`;
		}
	}

	async function goToSettings() {
		window.location.href = '/settings';
	}

	onMount(() => {
		fetchStatus();
		fetchConfig();
		const interval = setInterval(fetchStatus, 3000);
		return () => clearInterval(interval);
	});
</script>

<div class="space-y-6">
	<div class="flex items-center justify-between">
		<h2 class="text-2xl font-bold text-green-500">Dashboard</h2>
		<button
			onclick={fetchStatus}
			class="btn-secondary text-sm"
		>
			🔄 Refresh
		</button>
	</div>

	{#if message}
		<div class="bg-gray-700 border border-gray-600 rounded px-4 py-2 text-sm">
			{message}
			<button onclick={() => (message = '')} class="ml-2 text-gray-400 hover:text-white">✕</button>
		</div>
	{/if}

	<!-- Minecraft Folder Section -->
	<div class="card">
		<h3 class="font-semibold mb-4 text-gray-300">📁 Minecraft Server Folder</h3>
		<div class="space-y-3">
			<div class="flex gap-2">
				<input
					type="text"
					bind:value={minecraftDir}
					placeholder={defaultMinecraftDir}
					class="input flex-1 font-mono text-sm"
				/>
				<button
					onclick={goToSettings}
					class="btn-primary"
				>
					Go to Settings
				</button>
			</div>
			<p class="text-sm text-gray-400">
				Use the absolute folder containing server.jar, server.properties, whitelist.json, ops.json, and banned-players.json.
			</p>
		</div>
	</div>

	<!-- Server Status Card -->
	<div class="card">
		<div class="flex items-center justify-between">
			<div class="flex items-center gap-4">
				<div
					class="w-4 h-4 rounded-full {serverStatus.running
						? 'bg-green-500 animate-pulse'
						: 'bg-red-500'}"
				></div>
				<div>
					<h3 class="text-lg font-semibold">Server Status</h3>
					<p class="text-gray-400">
						{serverStatus.running ? 'Online' : 'Offline'}
						{#if serverStatus.running && serverStatus.uptime}
							<span class="text-gray-500">• Uptime: {formatUptime(serverStatus.uptime)}</span>
						{/if}
					</p>
				</div>
			</div>
			<button
				onclick={toggleServer}
				disabled={loading}
				class="{serverStatus.running ? 'btn-danger' : 'btn-primary'} min-w-[120px]"
			>
				{#if loading}
					<span class="animate-spin">⏳</span>
				{:else}
					{serverStatus.running ? '⏹ Stop' : '▶ Start'}
				{/if}
			</button>
		</div>
	</div>

	<!-- Online Players Card -->
	<div class="card">
		<div class="flex items-center justify-between mb-3">
			<h3 class="text-lg font-semibold text-gray-300">
				👥 Online Players
				<span class="ml-2 px-2 py-0.5 bg-green-600 text-white text-sm rounded-full">
					{serverStatus.playerCount}
				</span>
			</h3>
			{#if serverStatus.running}
				<span class="text-xs text-gray-500">Updates automatically</span>
			{/if}
		</div>
		
		{#if !serverStatus.running}
			<p class="text-gray-500 text-center py-4">Server is offline</p>
		{:else if serverStatus.players.length === 0}
			<p class="text-gray-500 text-center py-4">No players online</p>
		{:else}
			<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
				{#each serverStatus.players as player}
					<div class="flex items-center gap-2 p-2 bg-gray-700 rounded">
						<div class="w-8 h-8 bg-gray-600 rounded overflow-hidden flex items-center justify-center">
							<img 
								src="https://mc-heads.net/avatar/{player}/32" 
								alt={player}
								class="w-full h-full"
								onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
							/>
						</div>
						<span class="text-sm font-medium truncate">{player}</span>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Quick Stats -->
	<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
		<div class="card">
			<div class="text-3xl mb-2">📁</div>
			<h4 class="font-semibold text-gray-300">File Manager</h4>
			<p class="text-sm text-gray-500">Manage server files and configs</p>
			<a href="/files" class="text-green-500 hover:underline text-sm mt-2 inline-block">Open →</a>
		</div>
		<div class="card">
			<div class="text-3xl mb-2">👥</div>
			<h4 class="font-semibold text-gray-300">Player Management</h4>
			<p class="text-sm text-gray-500">Whitelist, operators & bans</p>
			<a href="/players" class="text-green-500 hover:underline text-sm mt-2 inline-block">Open →</a>
		</div>
		<div class="card">
			<div class="text-3xl mb-2">💻</div>
			<h4 class="font-semibold text-gray-300">Console</h4>
			<p class="text-sm text-gray-500">View logs and send commands</p>
			<a href="/console" class="text-green-500 hover:underline text-sm mt-2 inline-block">Open →</a>
		</div>
	</div>

	<!-- Recent Logs -->
	<div class="card">
		<h3 class="text-lg font-semibold mb-3 text-gray-300">Recent Logs</h3>
		<div class="bg-gray-900 rounded p-3 font-mono text-sm max-h-64 overflow-y-auto">
			{#if recentLogs.length === 0}
				<p class="text-gray-500">No logs available. Start the server to see output.</p>
			{:else}
				{#each recentLogs as log}
					<div class="text-gray-400 py-0.5">{log}</div>
				{/each}
			{/if}
		</div>
	</div>
</div>
