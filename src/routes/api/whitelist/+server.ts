import { json } from '@sveltejs/kit';
import { readFile, writeFile } from 'fs/promises';
import { resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

interface WhitelistEntry {
	uuid?: string;
	name: string;
}

async function readWhitelist(file: string): Promise<WhitelistEntry[]> {
	try {
		const content = await readFile(file, 'utf-8');
		return JSON.parse(content);
	} catch {
		return [];
	}
}

async function saveWhitelist(file: string, whitelist: WhitelistEntry[]): Promise<void> {
	await writeFile(file, JSON.stringify(whitelist, null, 2), 'utf-8');
}

export const GET: RequestHandler = async () => {
	const whitelistFile = resolveMinecraftPath('whitelist.json');
	const whitelist = whitelistFile ? await readWhitelist(whitelistFile) : [];
	return json({ whitelist });
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, name } = await request.json();

	if (!name) {
		return json({ error: 'Player name required' }, { status: 400 });
	}

	const whitelistFile = resolveMinecraftPath('whitelist.json');
	if (!whitelistFile) {
		return json({ error: 'Invalid Minecraft server path' }, { status: 400 });
	}
	const whitelist = await readWhitelist(whitelistFile);

	switch (action) {
		case 'add': {
			if (whitelist.some((p) => p.name.toLowerCase() === name.toLowerCase())) {
				return json({ success: false, message: 'Player already whitelisted' });
			}
			whitelist.push({ name });
			await saveWhitelist(whitelistFile, whitelist);
			return json({ success: true, message: `Added ${name} to whitelist` });
		}

		case 'remove': {
			const index = whitelist.findIndex((p) => p.name.toLowerCase() === name.toLowerCase());
			if (index === -1) {
				return json({ success: false, message: 'Player not in whitelist' });
			}
			whitelist.splice(index, 1);
			await saveWhitelist(whitelistFile, whitelist);
			return json({ success: true, message: `Removed ${name} from whitelist` });
		}

		default:
			return json({ error: 'Unknown action' }, { status: 400 });
	}
};
