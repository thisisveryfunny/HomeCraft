import { json } from '@sveltejs/kit';
import { writeFile } from 'fs/promises';
import { join } from 'path';
import type { RequestHandler } from './$types';

const MC_SERVER_DIR = '/minecraft';

function isPathSafe(requestedPath: string): boolean {
const resolved = join(MC_SERVER_DIR, requestedPath);
return resolved.startsWith(MC_SERVER_DIR);
}

export const POST: RequestHandler = async ({ request }) => {
try {
const formData = await request.formData();
const file = formData.get('file') as File;
const path = formData.get('path') as string || '';

if (!file) {
return json({ error: 'No file provided' }, { status: 400 });
}

const targetPath = join(path, file.name);
if (!isPathSafe(targetPath)) {
return json({ error: 'Invalid path' }, { status: 400 });
}

const fullPath = join(MC_SERVER_DIR, targetPath);
const buffer = Buffer.from(await file.arrayBuffer());
await writeFile(fullPath, buffer);

return json({ success: true, message: `Uploaded ${file.name}` });
} catch (error) {
return json({ error: `Upload failed: ${error}` }, { status: 500 });
}
};
