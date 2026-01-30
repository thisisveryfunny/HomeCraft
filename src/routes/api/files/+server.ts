import { json } from '@sveltejs/kit';
import { readdir, readFile, writeFile, unlink, stat, mkdir } from 'fs/promises';
import { join, dirname } from 'path';
import type { RequestHandler } from './$types';

const MC_SERVER_DIR = '/minecraft';

function isPathSafe(requestedPath: string): boolean {
	const resolved = join(MC_SERVER_DIR, requestedPath);
	return resolved.startsWith(MC_SERVER_DIR);
}

export const GET: RequestHandler = async ({ url }) => {
	const path = url.searchParams.get('path') || '';
	
	if (!isPathSafe(path)) {
		return json({ error: 'Invalid path' }, { status: 400 });
	}

	const fullPath = join(MC_SERVER_DIR, path);

	try {
		const stats = await stat(fullPath);

		if (stats.isDirectory()) {
			const entries = await readdir(fullPath, { withFileTypes: true });
			const items = entries.map((entry) => ({
				name: entry.name,
				isDirectory: entry.isDirectory(),
				path: join(path, entry.name)
			}));
			items.sort((a, b) => {
				if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
				return a.name.localeCompare(b.name);
			});
			return json({ type: 'directory', items, path });
		} else {
			const content = await readFile(fullPath, 'utf-8');
			return json({ type: 'file', content, path });
		}
	} catch (error) {
		return json({ error: `Failed to read: ${error}` }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, path, content, newName } = await request.json();

	if (!isPathSafe(path)) {
		return json({ error: 'Invalid path' }, { status: 400 });
	}

	const fullPath = join(MC_SERVER_DIR, path);

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
				if (!newName || !isPathSafe(join(dirname(path), newName))) {
					return json({ error: 'Invalid new name' }, { status: 400 });
				}
				const newPath = join(MC_SERVER_DIR, dirname(path), newName);
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
