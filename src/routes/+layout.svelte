<script lang="ts">
	import '../app.css';
	import { page } from '$app/state';

	let { children } = $props();

	const navItems = [
		{ href: '/', label: 'Dashboard', icon: '🏠' },
		{ href: '/files', label: 'File Manager', icon: '📁' },
		{ href: '/console', label: 'Console', icon: '💻' },
		{ href: '/players', label: 'Player Management', icon: '👥' },
		{ href: '/settings', label: 'Settings', icon: '⚙️' }
	];
</script>

<div class="flex min-h-screen">
	<!-- Sidebar -->
	<aside class="w-64 bg-gray-800 border-r border-gray-700 flex flex-col">
		<div class="p-4 border-b border-gray-700">
			<h1 class="text-xl font-bold text-green-500 flex items-center gap-2">
				<span class="text-2xl">⛏️</span>
				HomeCraft
			</h1>
			<p class="text-gray-400 text-sm mt-1">Server Admin Panel</p>
		</div>
		<nav class="flex-1 p-4">
			<ul class="space-y-2">
				{#each navItems as item}
					<li>
						<a
							href={item.href}
							class="flex items-center gap-3 px-3 py-2 rounded transition-colors {page.url.pathname === item.href
								? 'bg-green-600 text-white'
								: 'text-gray-300 hover:bg-gray-700'}"
						>
							<span>{item.icon}</span>
							{item.label}
						</a>
					</li>
				{/each}
			</ul>
		</nav>
		<div class="p-4 border-t border-gray-700 text-xs text-gray-500">
			Minecraft Server Manager v1.0
		</div>
	</aside>

	<!-- Main Content -->
	<main class="flex-1 p-6 overflow-auto">
		{@render children()}
	</main>
</div>
