<script lang="ts">
	import { onMount } from 'svelte';

	interface Player {
		name: string;
		uuid?: string;
		level?: number;
		reason?: string;
	}

	interface ServerStatus {
		running: boolean;
		uptime: number | null;
		playerCount: number;
		players: string[];
	}

	let serverStatus = $state<ServerStatus>({ running: false, uptime: null, playerCount: 0, players: [] });
	let whitelist = $state<Player[]>([]);
	let ops = $state<Player[]>([]);
	let banned = $state<Player[]>([]);
	let newWhitelist = $state('');
	let newOp = $state('');
	let newBan = $state('');
	let banReason = $state('');
	let loading = $state(true);
	let message = $state('');
	let activeTab = $state<'player-list' | 'whitelist' | 'ops' | 'banned'>('player-list');

	async function fetchAll() {
		try {
			const [playersRes, whitelistRes, serverRes] = await Promise.all([
				fetch('/api/players'),
				fetch('/api/whitelist'),
				fetch('/api/server')
			]);
			const playersData = await playersRes.json();
			const whitelistData = await whitelistRes.json();
			const srvData = await serverRes.json();
			serverStatus = srvData.status;
			ops = playersData.ops;
			banned = playersData.banned;
			whitelist = whitelistData.whitelist;
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function fetchStatus() {
		try {
			const res = await fetch('/api/server');
			const data = await res.json();
			serverStatus = data.status;
		} catch (e) {
			console.error('Failed to fetch status:', e);
		} finally {
			loading = false;
		}
	}
	
	// Whitelist functions
	async function addToWhitelist() {
		if (!newWhitelist.trim()) return;
		loading = true;
		try {
			const res = await fetch('/api/whitelist', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'add', name: newWhitelist.trim() })
			});
			const data = await res.json();
			message = data.message;
			if (data.success) {
				newWhitelist = '';
				await fetchAll();
			}
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function removeFromWhitelist(name: string) {
		if (!confirm(`Remove ${name} from whitelist?`)) return;
		loading = true;
		try {
			const res = await fetch('/api/whitelist', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'remove', name })
			});
			const data = await res.json();
			message = data.message;
			if (data.success) await fetchAll();
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	// Ops functions
	async function addOp() {
		if (!newOp.trim()) return;
		loading = true;
		try {
			const res = await fetch('/api/players', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'add', type: 'ops', name: newOp.trim() })
			});
			const data = await res.json();
			message = data.message;
			if (data.success) {
				newOp = '';
				await fetchAll();
			}
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function removeOp(name: string) {
		if (!confirm(`Remove ${name} from operators?`)) return;
		loading = true;
		try {
			const res = await fetch('/api/players', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'remove', type: 'ops', name })
			});
			const data = await res.json();
			message = data.message;
			if (data.success) await fetchAll();
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	// Ban functions
	async function banPlayer() {
		if (!newBan.trim()) return;
		loading = true;
		try {
			const res = await fetch('/api/players', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'add',
					type: 'banned',
					name: newBan.trim(),
					reason: banReason.trim() || 'Banned by admin'
				})
			});
			const data = await res.json();
			message = data.message;
			if (data.success) {
				newBan = '';
				banReason = '';
				await fetchAll();
			}
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function unbanPlayer(name: string) {
		if (!confirm(`Unban ${name}?`)) return;
		loading = true;
		try {
			const res = await fetch('/api/players', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'remove', type: 'banned', name })
			});
			const data = await res.json();
			message = data.message;
			if (data.success) await fetchAll();
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		fetchAll()
		const interval = setInterval(fetchStatus, 3000);
		return () => clearInterval(interval);
	});
</script>

<div class="space-y-4">
	<h2 class="text-2xl font-bold text-green-500">Player Management</h2>

	{#if message}
		<div class="bg-gray-700 border border-gray-600 rounded px-4 py-2 text-sm">
			{message}
			<button onclick={() => (message = '')} class="ml-2 text-gray-400 hover:text-white">✕</button>
		</div>
	{/if}

	<!-- Tabs -->
	<div class="flex gap-2 border-b border-gray-700">
		<button
			onclick={() => (activeTab = 'player-list')}
			class="px-4 py-2 font-medium transition-colors {activeTab === 'player-list'
				? 'text-green-500 border-b-2 border-green-500'
				: 'text-gray-400 hover:text-white'}"
		>
			👥 Player List (serverStatus.playerCount)
			{#if serverStatus.running}
				<span class="ml-1 text-xs text-gray-500">({serverStatus.players.join(', ')})</span>
			{/if}
		</button>
		<button
			onclick={() => (activeTab = 'whitelist')}
			class="px-4 py-2 font-medium transition-colors {activeTab === 'whitelist'
				? 'text-green-500 border-b-2 border-green-500'
				: 'text-gray-400 hover:text-white'}"
		>
			📋 Whitelist ({whitelist.length})
		</button>
		<button
			onclick={() => (activeTab = 'ops')}
			class="px-4 py-2 font-medium transition-colors {activeTab === 'ops'
				? 'text-green-500 border-b-2 border-green-500'
				: 'text-gray-400 hover:text-white'}"
		>
			👑 Operators ({ops.length})
		</button>
		<button
			onclick={() => (activeTab = 'banned')}
			class="px-4 py-2 font-medium transition-colors {activeTab === 'banned'
				? 'text-green-500 border-b-2 border-green-500'
				: 'text-gray-400 hover:text-white'}"
		>
			🚫 Banned ({banned.length})
		</button>
	</div>

	{#if activeTab === 'whitelist'}
		<!-- Whitelist Tab -->
		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Add to Whitelist</h3>
			<div class="flex gap-2">
				<input
					type="text"
					bind:value={newWhitelist}
					placeholder="Player name..."
					class="input flex-1"
					onkeydown={(e) => e.key === 'Enter' && addToWhitelist()}
				/>
				<button onclick={addToWhitelist} disabled={loading || !newWhitelist.trim()} class="btn-primary">
					➕ Add
				</button>
			</div>
		</div>

		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Whitelisted Players</h3>
			{#if loading}
				<div class="text-center py-8 text-gray-400">Loading...</div>
			{:else if whitelist.length === 0}
				<p class="text-gray-500 text-center py-8">No players whitelisted.</p>
			{:else}
				<div class="space-y-2">
					{#each whitelist as player}
						<div class="flex items-center justify-between p-3 bg-gray-700 rounded hover:bg-gray-600 group">
							<div class="flex items-center gap-3">
								<div class="w-8 h-8 bg-gray-600 rounded overflow-hidden flex items-center justify-center">
									<img 
										src="https://mc-heads.net/avatar/{player.name}/32" 
										alt={player.name}
										class="w-full h-full"
										onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
									/>
								</div>
								<div>
									<div class="font-medium">{player.name}</div>
									{#if player.uuid}
										<div class="text-xs text-gray-500">{player.uuid}</div>
									{/if}
								</div>
							</div>
							<button
								onclick={() => removeFromWhitelist(player.name)}
								class="opacity-0 group-hover:opacity-100 btn-danger text-sm"
							>
								Remove
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<div class="card bg-gray-800/50">
			<h4 class="font-semibold text-gray-300 mb-2">ℹ️ About Whitelist</h4>
			<p class="text-sm text-gray-400">
				The whitelist restricts who can join your server. Enable it in Settings by setting 
				<code class="text-green-400">Whitelist Enabled</code> to On, or use the 
				<code class="text-green-400">whitelist on</code> command in the console.
			</p>
		</div>
	{:else if activeTab === 'ops'}
		<!-- Operators Tab -->
		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Add Operator</h3>
			<div class="flex gap-2">
				<input
					type="text"
					bind:value={newOp}
					placeholder="Player name..."
					class="input flex-1"
					onkeydown={(e) => e.key === 'Enter' && addOp()}
				/>
				<button onclick={addOp} disabled={loading || !newOp.trim()} class="btn-primary">
					👑 Make Op
				</button>
			</div>
		</div>

		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Server Operators</h3>
			{#if loading}
				<div class="text-center py-8 text-gray-400">Loading...</div>
			{:else if ops.length === 0}
				<p class="text-gray-500 text-center py-8">No operators configured.</p>
			{:else}
				<div class="space-y-2">
					{#each ops as op}
						<div class="flex items-center justify-between p-3 bg-gray-700 rounded hover:bg-gray-600 group">
							<div class="flex items-center gap-3">
								<div class="w-8 h-8 bg-gray-600 rounded overflow-hidden flex items-center justify-center">
									<img 
										src="https://mc-heads.net/avatar/{op.name}/32" 
										alt={op.name}
										class="w-full h-full"
										onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
									/>
								</div>
								<div>
									<div class="font-medium">{op.name}</div>
									<div class="text-xs text-gray-500">Level {op.level || 4}</div>
								</div>
							</div>
							<button
								onclick={() => removeOp(op.name)}
								class="opacity-0 group-hover:opacity-100 btn-danger text-sm"
							>
								Remove
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{:else}
		<!-- Banned Tab -->
		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Ban Player</h3>
			<div class="space-y-2">
				<div class="flex gap-2">
					<input
						type="text"
						bind:value={newBan}
						placeholder="Player name..."
						class="input flex-1"
						onkeydown={(e) => e.key === 'Enter' && banPlayer()}
					/>
					<button onclick={banPlayer} disabled={loading || !newBan.trim()} class="btn-danger">
						🚫 Ban
					</button>
				</div>
				<input
					type="text"
					bind:value={banReason}
					placeholder="Reason (optional)..."
					class="input w-full"
				/>
			</div>
		</div>

		<div class="card">
			<h3 class="font-semibold mb-3 text-gray-300">Banned Players</h3>
			{#if loading}
				<div class="text-center py-8 text-gray-400">Loading...</div>
			{:else if banned.length === 0}
				<p class="text-gray-500 text-center py-8">No banned players.</p>
			{:else}
				<div class="space-y-2">
					{#each banned as player}
						<div class="flex items-center justify-between p-3 bg-gray-700 rounded hover:bg-gray-600 group">
							<div class="flex items-center gap-3">
								<div class="w-8 h-8 bg-gray-600 rounded overflow-hidden flex items-center justify-center">
									<img 
										src="https://mc-heads.net/avatar/{player.name}/32" 
										alt={player.name}
										class="w-full h-full"
										onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
									/>
								</div>
								<div>
									<div class="font-medium">{player.name}</div>
									<div class="text-xs text-gray-500">{player.reason || 'No reason'}</div>
								</div>
							</div>
							<button
								onclick={() => unbanPlayer(player.name)}
								class="opacity-0 group-hover:opacity-100 btn-primary text-sm"
							>
								Unban
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>