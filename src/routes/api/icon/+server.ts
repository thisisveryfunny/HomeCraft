import { json } from '@sveltejs/kit';
import sharp from 'sharp';
import { writeFile, readFile, unlink } from 'fs/promises';
import { resolveMinecraftPath } from '$lib/server/config';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => {
	try {
		const iconPath = resolveMinecraftPath('server-icon.png');
		if (!iconPath) {
			return json({ exists: false, icon: null });
		}
		const iconBuffer = await readFile(iconPath);
		const base64 = iconBuffer.toString('base64');
		return json({ exists: true, icon: `data:image/png;base64,${base64}` });
	} catch {
		return json({ exists: false, icon: null });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	try {
		const formData = await request.formData();
		const file = formData.get('icon') as File;

		if (!file) {
			return json({ error: 'No file provided' }, { status: 400 });
		}

		const buffer = Buffer.from(await file.arrayBuffer());

		// Resize to exactly 64x64 and convert to PNG
		const processedImage = await sharp(buffer)
			.resize(64, 64, {
				fit: 'cover',
				position: 'center'
			})
			.png()
			.toBuffer();

		const iconPath = resolveMinecraftPath('server-icon.png');
		if (!iconPath) {
			return json({ error: 'Invalid Minecraft server path' }, { status: 400 });
		}

		await writeFile(iconPath, processedImage);

		const base64 = processedImage.toString('base64');
		return json({
			success: true,
			message: 'Server icon updated successfully',
			icon: `data:image/png;base64,${base64}`
		});
	} catch (error) {
		return json({ error: `Failed to process image: ${error}` }, { status: 500 });
	}
};

export const DELETE: RequestHandler = async () => {
	try {
		const iconPath = resolveMinecraftPath('server-icon.png');
		if (!iconPath) {
			return json({ success: false, message: 'Invalid Minecraft server path' });
		}
		await unlink(iconPath);
		return json({ success: true, message: 'Server icon removed' });
	} catch {
		return json({ success: false, message: 'No icon to remove' });
	}
};
