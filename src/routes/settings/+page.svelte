<script lang="ts">
	import { onMount } from 'svelte';

	interface Properties {
		[key: string]: string;
	}

	let properties = $state<Properties>({});
	let loading = $state(true);
	let saving = $state(false);
	let message = $state('');

	// MOTD Editor state
	let motdLine1 = $state('');
	let motdLine2 = $state('');
	let selectedColor = $state('f');
	let magicTextEnabled = $state(false);

	// Server Icon state
	let serverIcon = $state<string | null>(null);
	let iconLoading = $state(false);

	// Minecraft color codes
	const mcColors = [
		{ code: '0', name: 'Black', hex: '#000000' },
		{ code: '1', name: 'Dark Blue', hex: '#0000AA' },
		{ code: '2', name: 'Dark Green', hex: '#00AA00' },
		{ code: '3', name: 'Dark Aqua', hex: '#00AAAA' },
		{ code: '4', name: 'Dark Red', hex: '#AA0000' },
		{ code: '5', name: 'Dark Purple', hex: '#AA00AA' },
		{ code: '6', name: 'Gold', hex: '#FFAA00' },
		{ code: '7', name: 'Gray', hex: '#AAAAAA' },
		{ code: '8', name: 'Dark Gray', hex: '#555555' },
		{ code: '9', name: 'Blue', hex: '#5555FF' },
		{ code: 'a', name: 'Green', hex: '#55FF55' },
		{ code: 'b', name: 'Aqua', hex: '#55FFFF' },
		{ code: 'c', name: 'Red', hex: '#FF5555' },
		{ code: 'd', name: 'Light Purple', hex: '#FF55FF' },
		{ code: 'e', name: 'Yellow', hex: '#FFFF55' },
		{ code: 'f', name: 'White', hex: '#FFFFFF' }
	];

	const formatCodes = [
		{ code: 'l', name: 'Bold', icon: 'B', style: 'font-bold' },
		{ code: 'o', name: 'Italic', icon: 'I', style: 'italic' },
		{ code: 'n', name: 'Underline', icon: 'U', style: 'underline' },
		{ code: 'm', name: 'Strikethrough', icon: 'S', style: 'line-through' },
		{ code: 'k', name: 'Magic/Obfuscated', icon: '✨', style: '' }
	];

	const importantSettings = [
		{ key: 'server-port', label: 'Server Port', type: 'number' },
		{ key: 'max-players', label: 'Max Players', type: 'number' },
		{ key: 'gamemode', label: 'Default Gamemode', type: 'select', options: ['survival', 'creative', 'adventure', 'spectator'] },
		{ key: 'difficulty', label: 'Difficulty', type: 'select', options: ['peaceful', 'easy', 'normal', 'hard'] },
		{ key: 'pvp', label: 'PvP Enabled', type: 'boolean' },
		{ key: 'white-list', label: 'Whitelist Enabled', type: 'boolean' },
		{ key: 'online-mode', label: 'Online Mode (Auth)', type: 'boolean' },
		{ key: 'allow-flight', label: 'Allow Flight', type: 'boolean' },
		{ key: 'spawn-monsters', label: 'Spawn Monsters', type: 'boolean' },
		{ key: 'spawn-animals', label: 'Spawn Animals', type: 'boolean' },
		{ key: 'view-distance', label: 'View Distance', type: 'number' },
		{ key: 'simulation-distance', label: 'Simulation Distance', type: 'number' },
		{ key: 'level-name', label: 'World Name', type: 'text' },
		{ key: 'level-seed', label: 'World Seed', type: 'text' },
		{ key: 'hardcore', label: 'Hardcore Mode', type: 'boolean' },
		{ key: 'enable-command-block', label: 'Command Blocks', type: 'boolean' },
	];

	function parseMotd(motd: string) {
		const lines = motd.split('\\n');
		motdLine1 = lines[0] || '';
		motdLine2 = lines[1] || '';
	}

	function updateMotd() {
		const motd = motdLine2 ? `${motdLine1}\\n${motdLine2}` : motdLine1;
		properties['motd'] = motd;
	}

	function insertCode(code: string, lineNum: 1 | 2) {
		const insertion = `§${code}`;
		if (lineNum === 1) {
			motdLine1 += insertion;
		} else {
			motdLine2 += insertion;
		}
		updateMotd();
	}

	function insertColorCode(lineNum: 1 | 2) {
		insertCode(selectedColor, lineNum);
	}

	function insertFormatCode(code: string, lineNum: 1 | 2) {
		insertCode(code, lineNum);
	}

	function insertReset(lineNum: 1 | 2) {
		insertCode('r', lineNum);
	}

	// Parse MOTD text to styled HTML for preview
	function renderMotdPreview(text: string): string {
		let result = '';
		let currentColor = '#FFFFFF';
		let isBold = false;
		let isItalic = false;
		let isUnderline = false;
		let isStrike = false;
		let isMagic = false;

		let i = 0;
		while (i < text.length) {
			if (text[i] === '§' && i + 1 < text.length) {
				const code = text[i + 1].toLowerCase();
				const colorMatch = mcColors.find(c => c.code === code);
				if (colorMatch) {
					currentColor = colorMatch.hex;
					isBold = false; isItalic = false; isUnderline = false; isStrike = false; isMagic = false;
				} else if (code === 'l') isBold = true;
				else if (code === 'o') isItalic = true;
				else if (code === 'n') isUnderline = true;
				else if (code === 'm') isStrike = true;
				else if (code === 'k') isMagic = true;
				else if (code === 'r') {
					currentColor = '#FFFFFF';
					isBold = false; isItalic = false; isUnderline = false; isStrike = false; isMagic = false;
				}
				i += 2;
			} else {
				let style = `color: ${currentColor};`;
				if (isBold) style += 'font-weight: bold;';
				if (isItalic) style += 'font-style: italic;';
				if (isUnderline) style += 'text-decoration: underline;';
				if (isStrike) style += 'text-decoration: line-through;';
				const char = isMagic ? '<span class="magic-text">▓</span>' : text[i];
				result += `<span style="${style}">${char}</span>`;
				i++;
			}
		}
		return result;
	}

	async function fetchProperties() {
		try {
			const res = await fetch('/api/properties');
			const data = await res.json();
			properties = data.properties;
			parseMotd(properties['motd'] || '');
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function fetchIcon() {
		try {
			const res = await fetch('/api/icon');
			const data = await res.json();
			if (data.exists) {
				serverIcon = data.icon;
			}
		} catch (e) {
			console.error('Failed to fetch icon:', e);
		}
	}

	async function uploadIcon(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		iconLoading = true;
		const formData = new FormData();
		formData.append('icon', file);

		try {
			const res = await fetch('/api/icon', {
				method: 'POST',
				body: formData
			});
			const data = await res.json();
			if (data.success) {
				serverIcon = data.icon;
				message = data.message;
			} else {
				message = data.error;
			}
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			iconLoading = false;
			input.value = '';
		}
	}

	async function removeIcon() {
		if (!confirm('Remove server icon?')) return;
		iconLoading = true;
		try {
			const res = await fetch('/api/icon', { method: 'DELETE' });
			const data = await res.json();
			message = data.message;
			if (data.success) serverIcon = null;
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			iconLoading = false;
		}
	}

	async function saveProperties() {
		saving = true;
		updateMotd();
		try {
			const res = await fetch('/api/properties', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ properties })
			});
			const data = await res.json();
			message = data.message || data.error;
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			saving = false;
		}
	}

	function updateProperty(key: string, value: string | boolean) {
		properties[key] = String(value);
	}

	onMount(() => {
		fetchProperties();
		fetchIcon();
	});
</script>

<style>
	@keyframes magic-scramble {
		0%, 100% { content: '▓'; }
		25% { content: '░'; }
		50% { content: '▒'; }
		75% { content: '█'; }
	}
	:global(.magic-text) {
		animation: magic-scramble 0.1s infinite;
		display: inline-block;
	}
</style>

<div class="space-y-4">
	<div class="flex items-center justify-between">
		<h2 class="text-2xl font-bold text-green-500">Server Settings</h2>
		<button
			onclick={saveProperties}
			disabled={saving || loading}
			class="btn-primary"
		>
			{saving ? '⏳ Saving...' : '💾 Save Changes'}
		</button>
	</div>

	{#if message}
		<div class="bg-gray-700 border border-gray-600 rounded px-4 py-2 text-sm">
			{message}
			<button onclick={() => (message = '')} class="ml-2 text-gray-400 hover:text-white">✕</button>
		</div>
	{/if}

	{#if loading}
		<div class="card text-center py-12 text-gray-400">Loading settings...</div>
	{:else}
		<!-- Server Icon Section -->
		<div class="card">
			<h3 class="font-semibold mb-4 text-gray-300">🖼️ Server Icon</h3>
			<div class="flex items-start gap-6">
				<div class="flex flex-col items-center gap-2">
					<div class="w-16 h-16 bg-gray-700 rounded border-2 border-gray-600 overflow-hidden flex items-center justify-center">
						{#if serverIcon}
							<img src={serverIcon} alt="Server Icon" class="w-full h-full object-cover" />
						{:else}
							<span class="text-2xl text-gray-500">🎮</span>
						{/if}
					</div>
					<span class="text-xs text-gray-500">64×64 PNG</span>
				</div>
				<div class="flex-1 space-y-3">
					<p class="text-sm text-gray-400">
						Upload a custom image for your server. It will be automatically resized to 64×64 pixels and converted to PNG format.
					</p>
					<div class="flex gap-2">
						<label class="btn-primary text-sm cursor-pointer {iconLoading ? 'opacity-50' : ''}">
							{iconLoading ? '⏳ Processing...' : '📤 Upload Image'}
							<input type="file" accept="image/*" class="hidden" onchange={uploadIcon} disabled={iconLoading} />
						</label>
						{#if serverIcon}
							<button onclick={removeIcon} disabled={iconLoading} class="btn-danger text-sm">
								🗑 Remove
							</button>
						{/if}
					</div>
				</div>
			</div>
		</div>

		<!-- MOTD Editor Section -->
		<div class="card">
			<h3 class="font-semibold mb-4 text-gray-300">📝 Server Message (MOTD)</h3>
			
			<!-- Color Palette -->
			<div class="mb-4">
				<label class="text-sm text-gray-400 block mb-2">Color Palette</label>
				<div class="flex flex-wrap gap-1">
					{#each mcColors as color}
						<button
							onclick={() => (selectedColor = color.code)}
							title={color.name}
							class="w-7 h-7 rounded border-2 transition-all {selectedColor === color.code ? 'border-white scale-110' : 'border-gray-600 hover:border-gray-400'}"
							style="background-color: {color.hex};"
						></button>
					{/each}
				</div>
			</div>

			<!-- Format Buttons -->
			<div class="mb-4">
				<label class="text-sm text-gray-400 block mb-2">Formatting</label>
				<div class="flex flex-wrap gap-2">
					{#each formatCodes as fmt}
						<button
							onclick={() => insertFormatCode(fmt.code, 1)}
							title="{fmt.name} (§{fmt.code})"
							class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm {fmt.style} border border-gray-600"
						>
							{fmt.icon}
						</button>
					{/each}
					<button
						onclick={() => insertReset(1)}
						title="Reset Formatting (§r)"
						class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm border border-gray-600"
					>
						↺ Reset
					</button>
				</div>
			</div>

			<!-- Line 1 -->
			<div class="mb-3">
				<div class="flex items-center justify-between mb-1">
					<label class="text-sm text-gray-400">Line 1</label>
					<button onclick={() => insertColorCode(1)} class="text-xs btn-secondary py-1 px-2">
						+ Add Color
					</button>
				</div>
				<input
					type="text"
					bind:value={motdLine1}
					oninput={updateMotd}
					placeholder="Welcome to my server!"
					class="input w-full font-mono"
				/>
			</div>

			<!-- Line 2 -->
			<div class="mb-4">
				<div class="flex items-center justify-between mb-1">
					<label class="text-sm text-gray-400">Line 2 (optional)</label>
					<button onclick={() => insertColorCode(2)} class="text-xs btn-secondary py-1 px-2">
						+ Add Color
					</button>
				</div>
				<input
					type="text"
					bind:value={motdLine2}
					oninput={updateMotd}
					placeholder="A Minecraft Server"
					class="input w-full font-mono"
				/>
			</div>

			<!-- Preview -->
			<div class="bg-gray-900 rounded p-4 border border-gray-700">
				<label class="text-xs text-gray-500 block mb-2">Preview</label>
				<div class="flex items-center gap-3">
					<div class="w-12 h-12 bg-gray-700 rounded overflow-hidden flex-shrink-0">
						{#if serverIcon}
							<img src={serverIcon} alt="Icon" class="w-full h-full object-cover" />
						{:else}
							<div class="w-full h-full flex items-center justify-center text-gray-500">🎮</div>
						{/if}
					</div>
					<div class="font-mono text-sm">
						<div>{@html renderMotdPreview(motdLine1) || '<span class="text-gray-500">Line 1...</span>'}</div>
						<div>{@html renderMotdPreview(motdLine2) || '<span class="text-gray-500">Line 2...</span>'}</div>
					</div>
				</div>
			</div>

			<!-- Quick Reference -->
			<details class="mt-4">
				<summary class="text-sm text-gray-400 cursor-pointer hover:text-gray-300">
					📖 Formatting Reference
				</summary>
				<div class="mt-2 p-3 bg-gray-900 rounded text-xs text-gray-400 space-y-1">
					<p><code class="text-green-400">§0-§9, §a-§f</code> - Color codes (click palette above)</p>
					<p><code class="text-green-400">§l</code> - <strong>Bold</strong></p>
					<p><code class="text-green-400">§o</code> - <em>Italic</em></p>
					<p><code class="text-green-400">§n</code> - <span class="underline">Underline</span></p>
					<p><code class="text-green-400">§m</code> - <span class="line-through">Strikethrough</span></p>
					<p><code class="text-green-400">§k</code> - Obfuscated/Magic text (animated scramble effect)</p>
					<p><code class="text-green-400">§r</code> - Reset all formatting</p>
					<p class="mt-2 text-yellow-400">⚠️ Note: §k "magic" text is the only animation possible in MOTD</p>
				</div>
			</details>
		</div>

		<!-- Important Settings -->
		<div class="card">
			<h3 class="font-semibold mb-4 text-gray-300">⚙️ Server Configuration</h3>
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
				{#each importantSettings as setting}
					<div class="space-y-1">
						<label class="text-sm text-gray-400">{setting.label}</label>
						{#if setting.type === 'boolean'}
							<div class="flex items-center gap-3">
								<button
									onclick={() => updateProperty(setting.key, properties[setting.key] === 'true' ? 'false' : 'true')}
									class="w-12 h-6 rounded-full transition-colors {properties[setting.key] === 'true' ? 'bg-green-600' : 'bg-gray-600'} relative"
								>
									<div
										class="w-5 h-5 bg-white rounded-full absolute top-0.5 transition-transform {properties[setting.key] === 'true' ? 'translate-x-6' : 'translate-x-0.5'}"
									></div>
								</button>
								<span class="text-sm">{properties[setting.key] === 'true' ? 'Enabled' : 'Disabled'}</span>
							</div>
						{:else if setting.type === 'select'}
							<select
								value={properties[setting.key]}
								onchange={(e) => updateProperty(setting.key, e.currentTarget.value)}
								class="input w-full"
							>
								{#each setting.options || [] as option}
									<option value={option}>{option}</option>
								{/each}
							</select>
						{:else}
							<input
								type={setting.type}
								value={properties[setting.key] || ''}
								oninput={(e) => updateProperty(setting.key, e.currentTarget.value)}
								class="input w-full"
							/>
						{/if}
					</div>
				{/each}
			</div>
		</div>

		<!-- All Properties -->
		<details class="card">
			<summary class="font-semibold text-gray-300 cursor-pointer">
				Advanced Settings (All Properties)
			</summary>
			<div class="mt-4 space-y-2 max-h-96 overflow-y-auto">
				{#each Object.entries(properties).sort((a, b) => a[0].localeCompare(b[0])) as [key, value]}
					<div class="flex gap-2 items-center">
						<label class="w-1/3 text-sm text-gray-400 truncate" title={key}>{key}</label>
						<input
							type="text"
							value={value}
							oninput={(e) => updateProperty(key, e.currentTarget.value)}
							class="input flex-1 text-sm"
						/>
					</div>
				{/each}
			</div>
		</details>

		<!-- Info -->
		<div class="card bg-gray-800/50">
			<h4 class="font-semibold text-gray-300 mb-2">⚠️ Important</h4>
			<p class="text-sm text-gray-400">
				Changes to server settings require a server restart to take effect.
				Make sure to stop the server before modifying critical settings.
			</p>
		</div>
	{/if}
</div>