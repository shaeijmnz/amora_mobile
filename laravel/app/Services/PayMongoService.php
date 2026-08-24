<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class PayMongoService
{
    private function secret(): string
    {
        $key = (string) config('services.paymongo.secret_key');
        if ($key === '') {
            throw new RuntimeException('PayMongo is not configured. Add PAYMONGO_SECRET_KEY to Laravel .env.');
        }

        return $key;
    }

    private function client()
    {
        return Http::withBasicAuth($this->secret(), '')
            ->acceptJson()
            ->asJson();
    }

    /**
     * Create a Hosted Checkout Session (v2).
     *
     * @param  array<int, array{name: string, amount: int, quantity: int}>  $lineItems  amount in centavos
     * @return array{id: string, checkout_url: string, attributes: array}
     */
    public function createCheckoutSession(array $payload): array
    {
        $response = $this->client()->post('https://api.paymongo.com/v1/checkout_sessions', [
            'data' => [
                'attributes' => $payload,
            ],
        ]);

        if (! $response->successful()) {
            $message = $response->json('errors.0.detail')
                ?? $response->json('errors.0.title')
                ?? 'PayMongo checkout failed ('.$response->status().').';
            throw new RuntimeException($message);
        }

        $data = $response->json('data') ?? [];
        $attributes = $data['attributes'] ?? [];
        $checkoutUrl = $attributes['checkout_url'] ?? null;
        $id = $data['id'] ?? null;

        if (! $id || ! $checkoutUrl) {
            throw new RuntimeException('PayMongo did not return a checkout URL.');
        }

        return [
            'id' => $id,
            'checkout_url' => $checkoutUrl,
            'attributes' => $attributes,
        ];
    }

    public function retrieveCheckoutSession(string $checkoutId): array
    {
        $response = $this->client()->get('https://api.paymongo.com/v1/checkout_sessions/'.$checkoutId);

        if (! $response->successful()) {
            $message = $response->json('errors.0.detail')
                ?? 'Could not retrieve PayMongo session ('.$response->status().').';
            throw new RuntimeException($message);
        }

        return $response->json('data') ?? [];
    }

    public function checkoutSessionIsPaid(array $sessionData): bool
    {
        $attributes = $sessionData['attributes'] ?? [];
        $status = strtolower((string) ($attributes['status'] ?? ''));
        if (in_array($status, ['paid', 'active'], true) && ! empty($attributes['payments'])) {
            return true;
        }

        $payments = $attributes['payments'] ?? [];
        foreach ($payments as $payment) {
            $paymentStatus = strtolower((string) data_get($payment, 'attributes.status', data_get($payment, 'status', '')));
            if ($paymentStatus === 'paid') {
                return true;
            }
        }

        // Some payloads nest payment under payments.*.attributes
        if ($status === 'paid') {
            return true;
        }

        return false;
    }

    public function firstPaymentId(array $sessionData): ?string
    {
        $payments = data_get($sessionData, 'attributes.payments', []);
        if (! is_array($payments) || $payments === []) {
            return null;
        }
        $first = $payments[0];
        if (is_array($first)) {
            return $first['id'] ?? data_get($first, 'attributes.id');
        }

        return null;
    }
}
