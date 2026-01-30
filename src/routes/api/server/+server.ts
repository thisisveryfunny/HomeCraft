import { json } from '@sveltejs/kit';
import { mcServer } from '$lib/server/minecraft';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => {
	return json({
		status: mcServer.getStatus(),
		logs: mcServer.getLogs().slice(-100)
	});
};

export const POST: RequestHandler = async ({ request }) => {
	const { action, command } = await request.json();

	switch (action) {
		case 'start':
			return json(mcServer.start());
		case 'stop':
			return json(mcServer.stop());
		case 'command':
			if (!command) {
				return json({ success: false, message: 'No command provided' });
			}
			return json(mcServer.sendCommand(command));
		default:
			return json({ success: false, message: 'Unknown action' });
	}
};
