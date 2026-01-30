import { json } from '@sveltejs/kit';
import { readFile, writeFile } from 'fs/promises';
import { join } from 'path';
import type { RequestHandler } from './$types';

const MC_SERVER_DIR = '/minecraft';
const WHITELIST_FILE = join(MC_SERVER_DIR, 'whitelist.json');

interface WhitelistEntry {
	uuid?: string;
	name: string;
}

async function readWhitelist(): Promise<WhitelistEntry[]> {
	try {
		const content = await readFile(WHITELIST_FILE, 'utf-8');
		return JSON.parse(content);
	} catch {
		return [];
	}
}

async function saveWhitelist(whitelist: WhitelistEntry[]): Promise<void> {
	await writeFile(WHITELIST_FILE, JSON.stringify(whitelist, null, 2), 'utf-8');
}

export const GET: RequestHandler = async () => {
	const whitelist = await readWhitelist();
	return json({ whitelist });
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, name } = await request.json();

	if (!name) {
		return json({ error: 'Player name required' }, { status: 400 });
	}

	const whitelist = await readWhitelist();

	switch (action) {
		case 'add': {
			if (whitelist.some((p) => p.name.toLowerCase() === name.toLowerCase())) {
				return json({ success: false, message: 'Player already whitelisted' });
			}
			whitelist.push({ name });
			await saveWhitelist(whitelist);
			return json({ success: true, message: `Added ${name} to whitelist` });
		}

		case 'remove': {
			const index = whitelist.findIndex((p) => p.name.toLowerCase() === name.toLowerCase());
			if (index === -1) {
				return json({ success: false, message: 'Player not in whitelist' });
			}
			whitelist.splice(index, 1);
			await saveWhitelist(whitelist);
			return json({ success: true, message: `Removed ${name} from whitelist` });
		}

		default:
			return json({ error: 'Unknown action' }, { status: 400 });
	}
};
