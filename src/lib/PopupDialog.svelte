<script lang="ts">
	import { tick } from 'svelte';
	import { closePopup, popupRequest } from './popup';

	let inputValue = $state('');
	let inputElement: HTMLInputElement | undefined = $state();
	let lastRequestId = $state<number | null>(null);

	$effect(() => {
		const request = $popupRequest;
		if (!request || request.id === lastRequestId) return;

		lastRequestId = request.id;
		inputValue = request.kind === 'prompt' ? request.defaultValue : '';

		if (request.kind === 'prompt') {
			tick().then(() => {
				inputElement?.focus();
				inputElement?.select();
			});
		}
	});

	function cancel() {
		const request = $popupRequest;
		if (!request) return;

		closePopup();
		if (request.kind === 'prompt') {
			request.resolve(null);
		} else {
			request.resolve(false);
		}
	}

	function accept() {
		const request = $popupRequest;
		if (!request) return;

		closePopup();
		if (request.kind === 'prompt') {
			request.resolve(inputValue.trim());
		} else {
			request.resolve(true);
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			event.preventDefault();
			cancel();
		}

		if (event.key === 'Enter' && $popupRequest?.kind === 'prompt') {
			event.preventDefault();
			accept();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if $popupRequest}
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
		<button class="absolute inset-0 cursor-default" aria-label="Cancel popup" onclick={cancel}></button>
		<div
			class="popup-card card relative w-full max-w-md shadow-2xl"
			aria-modal="true"
			role="dialog"
			aria-labelledby="popup-title"
			aria-describedby="popup-message"
		>
			<div class="space-y-4">
				<div>
					<h2 id="popup-title" class="text-lg font-semibold text-gray-100">{$popupRequest.title}</h2>
					<p id="popup-message" class="mt-2 text-sm leading-6 text-gray-300">{$popupRequest.message}</p>
				</div>

				{#if $popupRequest.kind === 'prompt'}
					<input
						bind:this={inputElement}
						bind:value={inputValue}
						type="text"
						placeholder={$popupRequest.placeholder}
						class="input w-full"
					/>
				{/if}

				<div class="flex justify-end gap-2">
					<button type="button" class="btn-secondary" onclick={cancel}>
						{$popupRequest.cancelText}
					</button>
					<button
						type="button"
						class={$popupRequest.tone === 'danger' ? 'btn-danger' : 'btn-primary'}
						onclick={accept}
					>
						{$popupRequest.confirmText}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.popup-card {
		animation: popup-slide-down 220ms ease-out;
	}

	@keyframes popup-slide-down {
		from {
			opacity: 0;
			transform: translateY(-55vh) scale(0.98);
		}

		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}
</style>
