import { json } from '@sveltejs/kit';
import { getConfig, getDefaultMinecraftDir, setMinecraftDir } from '$lib/server/config';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => {
	return json({
		config: getConfig(),
		defaults: {
			minecraftDir: getDefaultMinecraftDir()
		}
	});
};

export const POST: RequestHandler = async ({ request }) => {
	const { minecraftDir } = await request.json();

	if (!minecraftDir || typeof minecraftDir !== 'string' || !minecraftDir.trim()) {
		return json({ error: 'Minecraft server folder is required' }, { status: 400 });
	}

	try {
		const config = await setMinecraftDir(minecraftDir.trim());
		return json({ success: true, message: 'Minecraft server folder saved', config });
	} catch (error) {
		return json({ error: `Failed to save folder: ${error}` }, { status: 400 });
	}
};
