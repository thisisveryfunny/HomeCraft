import { json } from '@sveltejs/kit';
import { readdir, readFile, writeFile, unlink, stat, mkdir } from 'fs/promises';
import { dirname, posix } from 'path';
import { getMinecraftDir, joinVirtualPath, resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url }) => {
	const path = url.searchParams.get('path') || '';

	const fullPath = resolveMinecraftPath(path);
	if (!fullPath) {
		return json({ error: 'Invalid path' }, { status: 400 });
	}

	try {
		const stats = await stat(fullPath);

		if (stats.isDirectory()) {
			const entries = await readdir(fullPath, { withFileTypes: true });
			const items = entries.map((entry) => ({
				name: entry.name,
				isDirectory: entry.isDirectory(),
				path: joinVirtualPath(path, entry.name)
			}));
			items.sort((a, b) => {
				if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
				return a.name.localeCompare(b.name);
			});
			return json({ type: 'directory', items, path, root: getMinecraftDir() });
		} else {
			const content = await readFile(fullPath, 'utf-8');
			return json({ type: 'file', content, path, root: getMinecraftDir() });
		}
	} catch (error) {
		return json({ error: `Failed to read: ${error}` }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, path, content, newName } = await request.json();

	const fullPath = resolveMinecraftPath(path);
	if (!fullPath) {
		return json({ error: 'Invalid path' }, { status: 400 });
	}

	try {
		switch (action) {
			case 'save':
				await writeFile(fullPath, content, 'utf-8');
				return json({ success: true, message: 'File saved' });

			case 'delete':
				await unlink(fullPath);
				return json({ success: true, message: 'File deleted' });

			case 'create':
				await mkdir(dirname(fullPath), { recursive: true });
				await writeFile(fullPath, content || '', 'utf-8');
				return json({ success: true, message: 'File created' });

			case 'createDir':
				await mkdir(fullPath, { recursive: true });
				return json({ success: true, message: 'Directory created' });

			case 'rename':
				if (!newName) {
					return json({ error: 'Invalid new name' }, { status: 400 });
				}
				const newPath = resolveMinecraftPath(joinVirtualPath(posix.dirname(path), newName));
				if (!newPath) {
					return json({ error: 'Invalid new name' }, { status: 400 });
				}
				const { rename } = await import('fs/promises');
				await rename(fullPath, newPath);
				return json({ success: true, message: 'Renamed successfully' });

			default:
				return json({ error: 'Unknown action' }, { status: 400 });
		}
	} catch (error) {
		return json({ error: `Operation failed: ${error}` }, { status: 500 });
	}
};
