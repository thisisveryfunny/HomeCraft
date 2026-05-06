import { readFileSync } from 'fs';
import { mkdir, stat, writeFile } from 'fs/promises';
import path from 'path';

export interface HomeCraftConfig {
	minecraftDir: string;
}

const CONFIG_DIR = path.join(process.cwd(), '.homecraft');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

export function getDefaultMinecraftDir(): string {
	return process.platform === 'win32' ? 'C:\\minecraft' : '/minecraft';
}

function normalizeConfig(config: Partial<HomeCraftConfig>): HomeCraftConfig {
	return {
		minecraftDir: path.resolve(config.minecraftDir || getDefaultMinecraftDir())
	};
}

export function getConfig(): HomeCraftConfig {
	try {
		const content = readFileSync(CONFIG_FILE, 'utf-8');
		return normalizeConfig(JSON.parse(content));
	} catch {
		return normalizeConfig({});
	}
}

export async function saveConfig(config: HomeCraftConfig): Promise<void> {
	await mkdir(CONFIG_DIR, { recursive: true });
	await writeFile(CONFIG_FILE, `${JSON.stringify(normalizeConfig(config), null, 2)}\n`, 'utf-8');
}

export function getMinecraftDir(): string {
	return getConfig().minecraftDir;
}

export async function setMinecraftDir(minecraftDir: string): Promise<HomeCraftConfig> {
	const resolved = path.resolve(minecraftDir);
	const dirStat = await stat(resolved);
	if (!dirStat.isDirectory()) {
		throw new Error('Minecraft server path must be a directory');
	}

	const config = normalizeConfig({ minecraftDir: resolved });
	await saveConfig(config);
	return config;
}

export function toVirtualPath(filePath: string): string {
	return filePath.replace(/\\/g, '/');
}

export function joinVirtualPath(basePath: string, name: string): string {
	return path.posix.join(toVirtualPath(basePath), name);
}

export function resolveMinecraftPath(requestedPath = ''): string | null {
	const root = path.resolve(getMinecraftDir());
	const normalizedRequest = toVirtualPath(requestedPath).trim();

	if (
		path.isAbsolute(normalizedRequest) ||
		/^[a-zA-Z]:/.test(normalizedRequest) ||
		normalizedRequest.includes('\0')
	) {
		return null;
	}

	const segments = normalizedRequest.split('/').filter(Boolean);
	const resolved = path.resolve(root, ...segments);
	const relative = path.relative(root, resolved);
	const isSafe = relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));

	return isSafe ? resolved : null;
}
