<script lang="ts">
	import { onMount } from 'svelte';
	import { confirmPopup, promptPopup } from '$lib/popup';

	interface FileItem {
		name: string;
		isDirectory: boolean;
		path: string;
	}

	let currentPath = $state('');
	let items = $state<FileItem[]>([]);
	let fileContent = $state('');
	let editingFile = $state<string | null>(null);
	let loading = $state(true);
	let message = $state('');
	let rootPath = $state('Minecraft server');
	let showNewFileModal = $state(false);
	let newFileName = $state('');
	let newFileIsDir = $state(false);

	async function loadDirectory(path: string = '') {
		loading = true;
		try {
			const res = await fetch(`/api/files?path=${encodeURIComponent(path)}`);
			const data = await res.json();
			if (data.root) {
				rootPath = data.root;
			}
			if (data.type === 'directory') {
				currentPath = path;
				items = data.items;
				editingFile = null;
				fileContent = '';
			} else if (data.type === 'file') {
				fileContent = data.content;
				editingFile = path;
			} else if (data.error) {
				message = data.error;
			}
		} catch (e) {
			message = `Error: ${e}`;
		} finally {
			loading = false;
		}
	}

	async function saveFile() {
		if (!editingFile) return;
		try {
			const res = await fetch('/api/files', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'save', path: editingFile, content: fileContent })
			});
			const data = await res.json();
			message = data.message || data.error;
		} catch (e) {
			message = `Error: ${e}`;
		}
	}

	async function editFileName(path: string) {
		const newName = await promptPopup({
			title: 'Rename item',
			message: 'Enter the new name for this item.',
			defaultValue: path.split('/').pop() || '',
			confirmText: 'Rename'
		});
		if (!newName) return;
		try {
			const res = await fetch('/api/files', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'rename', path, newName })
			});
			const data = await res.json();
			message = data.message || data.error;
			if (data.success) loadDirectory(currentPath);
		} catch (e) {
			message = `Error: ${e}`;
		}
	}

	async function deleteItem(item: FileItem) {
		if (
			!(await confirmPopup({
				title: 'Delete file',
				message: `Delete ${item.name}? This action cannot be undone.`,
				confirmText: 'Delete',
				tone: 'danger'
			}))
		) return;
		try {
			const res = await fetch('/api/files', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'delete', path: item.path })
			});
			const data = await res.json();
			message = data.message || data.error;
			if (data.success) loadDirectory(currentPath);
		} catch (e) {
			message = `Error: ${e}`;
		}
	}

	async function createNew() {
		if (!newFileName.trim()) return;
		const path = currentPath ? `${currentPath}/${newFileName}` : newFileName;
		try {
			const res = await fetch('/api/files', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: newFileIsDir ? 'createDir' : 'create',
					path,
					content: ''
				})
			});
			const data = await res.json();
			message = data.message || data.error;
			if (data.success) {
				showNewFileModal = false;
				newFileName = '';
				loadDirectory(currentPath);
			}
		} catch (e) {
			message = `Error: ${e}`;
		}
	}

	async function uploadFile(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		const formData = new FormData();
		formData.append('file', file);
		formData.append('path', currentPath);

		try {
			const res = await fetch('/api/files/upload', {
				method: 'POST',
				body: formData
			});
			const data = await res.json();
			message = data.message || data.error;
			if (data.success) loadDirectory(currentPath);
		} catch (e) {
			message = `Error: ${e}`;
		}
		input.value = '';
	}

	function goUp() {
		const parts = currentPath.split('/').filter(Boolean);
		parts.pop();
		loadDirectory(parts.join('/'));
	}

	function getFileIcon(item: FileItem): string {
		if (item.isDirectory) return '📁';
		const ext = item.name.split('.').pop()?.toLowerCase();
		switch (ext) {
			case 'json': return '📋';
			case 'properties': return '⚙️';
			case 'txt': case 'log': return '📄';
			case 'jar': return '☕';
			case 'yml': case 'yaml': return '📝';
			default: return '📄';
		}
	}

	onMount(() => loadDirectory());
</script>

<div class="space-y-4">
	<div class="flex items-center justify-between">
		<h2 class="text-2xl font-bold text-green-500">File Manager</h2>
		<div class="flex gap-2">
			<button onclick={() => (showNewFileModal = true)} class="btn-primary text-sm">
				➕ New
			</button>
			<label class="btn-secondary text-sm cursor-pointer">
				📤 Upload
				<input type="file" class="hidden" onchange={uploadFile} />
			</label>
		</div>
	</div>

	{#if message}
		<div class="bg-gray-700 border border-gray-600 rounded px-4 py-2 text-sm">
			{message}
			<button onclick={() => (message = '')} class="ml-2 text-gray-400 hover:text-white">✕</button>
		</div>
	{/if}

	<!-- Breadcrumb -->
	<div class="card flex items-center gap-2 text-sm">
		<button onclick={() => loadDirectory('')} class="text-green-500 hover:underline truncate" title={rootPath}>{rootPath}</button>
		{#each currentPath.split('/').filter(Boolean) as segment, i}
			<span class="text-gray-500">/</span>
			<button
				onclick={() => loadDirectory(currentPath.split('/').slice(0, i + 1).join('/'))}
				class="text-green-500 hover:underline"
			>
				{segment}
			</button>
		{/each}
	</div>

	{#if editingFile}
		<!-- File Editor -->
		<div class="card">
			<div class="flex items-center justify-between mb-3">
				<h3 class="font-semibold text-gray-300">Editing: {editingFile.split('/').pop()}</h3>
				<div class="flex gap-2">
					<button onclick={saveFile} class="btn-primary text-sm">💾 Save</button>
					<button onclick={goUp} class="btn-secondary text-sm">← Back</button>
				</div>
			</div>
			<textarea
				bind:value={fileContent}
				class="w-full h-96 bg-gray-900 text-gray-100 font-mono text-sm p-3 rounded border border-gray-700 focus:outline-none focus:ring-2 focus:ring-green-500"
			></textarea>
		</div>
	{:else}
		<!-- File List -->
		<div class="card">
			{#if loading}
				<div class="text-center py-8 text-gray-400">Loading...</div>
			{:else}
				<div class="space-y-1">
					{#if currentPath}
						<button
							onclick={goUp}
							class="w-full flex items-center gap-3 p-2 rounded hover:bg-gray-700 text-left"
						>
							<span>📂</span>
							<span class="text-gray-400">..</span>
						</button>
					{/if}
					{#each items as item}
						<div class="flex items-center gap-2 p-2 rounded hover:bg-gray-700 group">
							<button
								onclick={() => loadDirectory(item.path)}
								class="flex-1 flex items-center gap-3 text-left"
							>
								<span>{getFileIcon(item)}</span>
								<span class="{item.isDirectory ? 'text-green-400' : 'text-gray-300'}">
									{item.name}
								</span>
							</button>
							<button
								onclick={() => editFileName(item.path)}
								class="opacity-0 group-hover:opacity-100 text-blue-400 hover:text-blue-300 p-1"
							>
								✏️
							</button>
							{#if !item.isDirectory}
								<button
									onclick={() => deleteItem(item)}
									class="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-300 p-1"
								>
									🗑
								</button>
							{/if}
						</div>
					{/each}
					{#if items.length === 0}
						<p class="text-gray-500 text-center py-4">Empty directory</p>
					{/if}
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- New File Modal -->
{#if showNewFileModal}
	<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
		<div class="card w-96">
			<h3 class="text-lg font-semibold mb-4">Create New</h3>
			<div class="space-y-4">
				<div class="flex gap-4">
					<label class="flex items-center gap-2">
						<input type="radio" bind:group={newFileIsDir} value={false} />
						<span>File</span>
					</label>
					<label class="flex items-center gap-2">
						<input type="radio" bind:group={newFileIsDir} value={true} />
						<span>Directory</span>
					</label>
				</div>
				<input
					type="text"
					bind:value={newFileName}
					placeholder="Name..."
					class="input w-full"
				/>
				<div class="flex gap-2 justify-end">
					<button onclick={() => (showNewFileModal = false)} class="btn-secondary">Cancel</button>
					<button onclick={createNew} class="btn-primary">Create</button>
				</div>
			</div>
		</div>
	</div>
{/if}
