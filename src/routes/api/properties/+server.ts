import { json } from '@sveltejs/kit';
import { readFile, writeFile } from 'fs/promises';
import { resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

interface ServerProperties {
	[key: string]: string;
}

async function readProperties(): Promise<ServerProperties> {
	const propertiesFile = resolveMinecraftPath('server.properties');
	if (!propertiesFile) return {};

	try {
		const content = await readFile(propertiesFile, 'utf-8');
		const props: ServerProperties = {};
		content.split('\n').forEach((line) => {
			if (line.trim() && !line.startsWith('#')) {
				const [key, ...valueParts] = line.split('=');
				if (key) {
					props[key.trim()] = valueParts.join('=').trim();
				}
			}
		});
		return props;
	} catch {
		return {};
	}
}

async function saveProperties(props: ServerProperties): Promise<void> {
	const propertiesFile = resolveMinecraftPath('server.properties');
	if (!propertiesFile) {
		throw new Error('Invalid Minecraft server path');
	}

	const lines = Object.entries(props).map(([key, value]) => `${key}=${value}`);
	lines.unshift('#Minecraft server properties');
	await writeFile(propertiesFile, lines.join('\n'), 'utf-8');
}

export const GET: RequestHandler = async () => {
	const properties = await readProperties();
	return json({ properties });
};

export const POST: RequestHandler = async ({ request }) => {
	const { properties } = await request.json();

	if (!properties || typeof properties !== 'object') {
		return json({ error: 'Invalid properties' }, { status: 400 });
	}

	try {
		await saveProperties(properties);
		return json({ success: true, message: 'Properties saved. Restart server to apply changes.' });
	} catch (error) {
		return json({ error: `Failed to save: ${error}` }, { status: 500 });
	}
};
