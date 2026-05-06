import { json } from '@sveltejs/kit';
import { writeFile } from 'fs/promises';
import { joinVirtualPath, resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const formData = await request.formData();
		const file = formData.get('file') as File;
		const path = (formData.get('path') as string) || '';

		if (!file) {
			return json({ error: 'No file provided' }, { status: 400 });
		}

		const targetPath = joinVirtualPath(path, file.name);
		const fullPath = resolveMinecraftPath(targetPath);
		if (!fullPath) {
			return json({ error: 'Invalid path' }, { status: 400 });
		}

		const buffer = Buffer.from(await file.arrayBuffer());
		await writeFile(fullPath, buffer);

		return json({ success: true, message: `Uploaded ${file.name}` });
	} catch (error) {
		return json({ error: `Upload failed: ${error}` }, { status: 500 });
	}
};
