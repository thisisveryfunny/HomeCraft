import { writable } from 'svelte/store';

export type PopupTone = 'default' | 'danger';
export type PopupKind = 'confirm' | 'prompt';

export interface ConfirmPopupOptions {
	title: string;
	message: string;
	confirmText?: string;
	cancelText?: string;
	tone?: PopupTone;
}

export interface PromptPopupOptions extends ConfirmPopupOptions {
	defaultValue?: string;
	placeholder?: string;
}

export type PopupRequest =
	| (Required<Pick<ConfirmPopupOptions, 'title' | 'message' | 'confirmText' | 'cancelText'>> & {
			id: number;
			kind: 'confirm';
			tone: PopupTone;
			resolve: (value: boolean) => void;
	  })
	| (Required<Pick<PromptPopupOptions, 'title' | 'message' | 'confirmText' | 'cancelText'>> & {
			id: number;
			kind: 'prompt';
			tone: PopupTone;
			defaultValue: string;
			placeholder: string;
			resolve: (value: string | null) => void;
	  });

let nextPopupId = 1;

export const popupRequest = writable<PopupRequest | null>(null);

export function confirmPopup(options: ConfirmPopupOptions): Promise<boolean> {
	return new Promise((resolve) => {
		popupRequest.set({
			id: nextPopupId++,
			kind: 'confirm',
			title: options.title,
			message: options.message,
			confirmText: options.confirmText ?? 'Confirm',
			cancelText: options.cancelText ?? 'Cancel',
			tone: options.tone ?? 'default',
			resolve
		});
	});
}

export function promptPopup(options: PromptPopupOptions): Promise<string | null> {
	return new Promise((resolve) => {
		popupRequest.set({
			id: nextPopupId++,
			kind: 'prompt',
			title: options.title,
			message: options.message,
			confirmText: options.confirmText ?? 'Confirm',
			cancelText: options.cancelText ?? 'Cancel',
			tone: options.tone ?? 'default',
			defaultValue: options.defaultValue ?? '',
			placeholder: options.placeholder ?? '',
			resolve
		});
	});
}

export function closePopup() {
	popupRequest.set(null);
}
