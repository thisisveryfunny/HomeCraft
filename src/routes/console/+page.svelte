<script lang="ts">
	import { onMount } from 'svelte';

	let logs = $state<string[]>([]);
	let command = $state('');
	let serverRunning = $state(false);
	let loading = $state(false);
	let autoScroll = $state(true);
	let consoleDiv: HTMLDivElement;

	async function fetchLogs() {
		try {
			const res = await fetch('/api/server');
			const data = await res.json();
			logs = data.logs;
			serverRunning = data.status.running;
			if (autoScroll && consoleDiv) {
				setTimeout(() => {
					consoleDiv.scrollTop = consoleDiv.scrollHeight;
				}, 50);
			}
		} catch (e) {
			console.error('Failed to fetch logs:', e);
		}
	}

	async function sendCommand() {
		if (!command.trim() || !serverRunning) return;
		loading = true;
		try {
			await fetch('/api/server', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'command', command: command.trim() })
			});
			command = '';
			await fetchLogs();
		} catch (e) {
			console.error('Failed to send command:', e);
		} finally {
			loading = false;
		}
	}

	async function toggleServer() {
		const action = serverRunning ? 'stop' : 'start';
		loading = true;
		try {
			await fetch('/api/server', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action })
			});
			await new Promise((r) => setTimeout(r, 1000));
			await fetchLogs();
		} catch (e) {
			console.error('Failed to toggle server:', e);
		} finally {
			loading = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			sendCommand();
		}
	}

	onMount(() => {
		fetchLogs();
		const interval = setInterval(fetchLogs, 2000);
		return () => clearInterval(interval);
	});
</script>

<div class="space-y-4 h-full flex flex-col">
	<div class="flex items-center justify-between">
		<h2 class="text-2xl font-bold text-green-500">Console</h2>
		<div class="flex items-center gap-4">
			<label class="flex items-center gap-2 text-sm text-gray-400">
				<input type="checkbox" bind:checked={autoScroll} class="rounded" />
				Auto-scroll
			</label>
			<div class="flex items-center gap-2">
				<div
					class="w-3 h-3 rounded-full {serverRunning ? 'bg-green-500' : 'bg-red-500'}"
				></div>
				<span class="text-sm text-gray-400">{serverRunning ? 'Online' : 'Offline'}</span>
			</div>
			<button
				onclick={toggleServer}
				disabled={loading}
				class="{serverRunning ? 'btn-danger' : 'btn-primary'} text-sm"
			>
				{serverRunning ? '⏹ Stop' : '▶ Start'}
			</button>
		</div>
	</div>

	<!-- Console Output -->
	<div
		bind:this={consoleDiv}
		class="flex-1 bg-gray-900 rounded-lg border border-gray-700 p-4 font-mono text-sm overflow-y-auto min-h-[400px] max-h-[600px]"
	>
		{#if logs.length === 0}
			<p class="text-gray-500">No logs yet. Start the server to see output.</p>
		{:else}
			{#each logs as log}
				<div class="py-0.5 {log.startsWith('[ERROR]') ? 'text-red-400' : log.startsWith('>') ? 'text-green-400' : 'text-gray-400'}">
					{log}
				</div>
			{/each}
		{/if}
	</div>

	<!-- Command Input -->
	<div class="card">
		<div class="flex gap-2">
			<span class="text-green-500 font-mono">&gt;</span>
			<input
				type="text"
				bind:value={command}
				onkeydown={handleKeydown}
				placeholder={serverRunning ? 'Type command...' : 'Server is offline'}
				disabled={!serverRunning || loading}
				class="input flex-1"
			/>
			<button
				onclick={sendCommand}
				disabled={!serverRunning || loading || !command.trim()}
				class="btn-primary"
			>
				Send
			</button>
		</div>
		<div class="mt-2 text-xs text-gray-500">
			Quick commands:
			<button onclick={() => { command = 'list'; sendCommand(); }} class="text-green-500 hover:underline mx-1">list</button>
			<button onclick={() => { command = 'say Hello!'; sendCommand(); }} class="text-green-500 hover:underline mx-1">say</button>
			<button onclick={() => { command = 'time set day'; sendCommand(); }} class="text-green-500 hover:underline mx-1">day</button>
			<button onclick={() => { command = 'weather clear'; sendCommand(); }} class="text-green-500 hover:underline mx-1">clear weather</button>
		</div>
	</div>
</div>