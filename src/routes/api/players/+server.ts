import { json } from '@sveltejs/kit';
import { readFile, writeFile } from 'fs/promises';
import { resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

interface OpsEntry {
	uuid?: string;
	name: string;
	level?: number;
	bypassesPlayerLimit?: boolean;
}

interface BannedEntry {
	uuid?: string;
	name: string;
	reason?: string;
	created?: string;
	source?: string;
	expires?: string;
}

async function readJsonFile<T>(file: string): Promise<T[]> {
	try {
		const content = await readFile(file, 'utf-8');
		return JSON.parse(content);
	} catch {
		return [];
	}
}

async function saveJsonFile<T>(file: string, data: T[]): Promise<void> {
	await writeFile(file, JSON.stringify(data, null, 2), 'utf-8');
}

export const GET: RequestHandler = async () => {
	const opsFile = resolveMinecraftPath('ops.json');
	const bannedFile = resolveMinecraftPath('banned-players.json');
	if (!opsFile || !bannedFile) {
		return json({ ops: [], banned: [] });
	}

	const [ops, banned] = await Promise.all([
		readJsonFile<OpsEntry>(opsFile),
		readJsonFile<BannedEntry>(bannedFile)
	]);
	return json({ ops, banned });
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, type, name, reason } = await request.json();

	if (!name) {
		return json({ error: 'Player name required' }, { status: 400 });
	}

	if (type === 'ops') {
		const opsFile = resolveMinecraftPath('ops.json');
		if (!opsFile) {
			return json({ error: 'Invalid Minecraft server path' }, { status: 400 });
		}
		const ops = await readJsonFile<OpsEntry>(opsFile);

		if (action === 'add') {
			if (ops.some((p) => p.name.toLowerCase() === name.toLowerCase())) {
				return json({ success: false, message: 'Player is already an operator' });
			}
			ops.push({ name, level: 4, bypassesPlayerLimit: false });
			await saveJsonFile(opsFile, ops);
			return json({ success: true, message: `Made ${name} an operator` });
		} else if (action === 'remove') {
			const index = ops.findIndex((p) => p.name.toLowerCase() === name.toLowerCase());
			if (index === -1) {
				return json({ success: false, message: 'Player is not an operator' });
			}
			ops.splice(index, 1);
			await saveJsonFile(opsFile, ops);
			return json({ success: true, message: `Removed ${name} from operators` });
		}
	} else if (type === 'banned') {
		const bannedFile = resolveMinecraftPath('banned-players.json');
		if (!bannedFile) {
			return json({ error: 'Invalid Minecraft server path' }, { status: 400 });
		}
		const banned = await readJsonFile<BannedEntry>(bannedFile);

		if (action === 'add') {
			if (banned.some((p) => p.name.toLowerCase() === name.toLowerCase())) {
				return json({ success: false, message: 'Player is already banned' });
			}
			banned.push({
				name,
				reason: reason || 'Banned by admin',
				created: new Date().toISOString(),
				source: 'HomeCraft Panel',
				expires: 'forever'
			});
			await saveJsonFile(bannedFile, banned);
			return json({ success: true, message: `Banned ${name}` });
		} else if (action === 'remove') {
			const index = banned.findIndex((p) => p.name.toLowerCase() === name.toLowerCase());
			if (index === -1) {
				return json({ success: false, message: 'Player is not banned' });
			}
			banned.splice(index, 1);
			await saveJsonFile(bannedFile, banned);
			return json({ success: true, message: `Unbanned ${name}` });
		}
	}

	return json({ error: 'Invalid action or type' }, { status: 400 });
};
