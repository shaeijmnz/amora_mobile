<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\OrderPaymentService;
use App\Services\PayMongoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class PayMongoWebhookController extends Controller
{
    public function __invoke(
        Request $request,
        PayMongoService $paymongo,
        OrderPaymentService $payments,
    ) {
        $secret = (string) config('services.paymongo.webhook_secret');
        if ($secret !== '') {
            $signatureHeader = $request->header('Paymongo-Signature', '');
            if (! $this->validSignature($request->getContent(), $signatureHeader, $secret)) {
                Log::warning('PayMongo webhook signature mismatch');

                return response()->json(['message' => 'Invalid signature.'], 400);
            }
        }

        $payload = $request->all();
        $type = data_get($payload, 'data.attributes.type')
            ?? data_get($payload, 'data.attributes.event')
            ?? data_get($payload, 'type');

        // checkout_session.payment.paid or payment.paid
        $checkoutId = data_get($payload, 'data.attributes.data.id')
            ?? data_get($payload, 'data.attributes.data.attributes.checkout_session_id')
            ?? data_get($payload, 'data.id');

        $metadataOrderId = data_get($payload, 'data.attributes.data.attributes.metadata.order_id')
            ?? data_get($payload, 'data.attributes.metadata.order_id');

        $paymentId = data_get($payload, 'data.attributes.data.id');
        if (is_string($type) && str_contains($type, 'checkout_session')) {
            $checkoutId = data_get($payload, 'data.attributes.data.id', $checkoutId);
            $paymentId = data_get($payload, 'data.attributes.data.attributes.payments.0.id', $paymentId);
        }

        $order = null;
        if ($metadataOrderId) {
            $order = Order::query()->find($metadataOrderId);
        }
        if (! $order && $checkoutId) {
            $order = Order::query()->where('paymongo_checkout_id', $checkoutId)->first();
        }

        if (! $order) {
            Log::info('PayMongo webhook: order not found', ['type' => $type, 'checkout' => $checkoutId]);

            return response()->json(['message' => 'Ignored.']);
        }

        if ($order->payment_status === 'paid') {
            return response()->json(['message' => 'Already paid.']);
        }

        $shouldMarkPaid = is_string($type) && (
            str_contains($type, 'payment.paid')
            || str_contains($type, 'checkout_session.payment.paid')
        );

        if (! $shouldMarkPaid && $order->paymongo_checkout_id) {
            try {
                $session = $paymongo->retrieveCheckoutSession($order->paymongo_checkout_id);
                $shouldMarkPaid = $paymongo->checkoutSessionIsPaid($session);
                $paymentId = $paymentId ?: $paymongo->firstPaymentId($session);
            } catch (\Throwable $e) {
                Log::warning('PayMongo webhook verify failed: '.$e->getMessage());
            }
        }

        if ($shouldMarkPaid) {
            try {
                $payments->markPaid($order, is_string($paymentId) ? $paymentId : null);
            } catch (ValidationException $e) {
                Log::error('PayMongo paid but stock failed', ['order' => $order->id, 'errors' => $e->errors()]);

                return response()->json(['message' => 'Stock error', 'errors' => $e->errors()], 422);
            }
        }

        return response()->json(['message' => 'OK']);
    }

    private function validSignature(string $payload, string $header, string $secret): bool
    {
        // Format: t=timestamp,te=test_signature,li=live_signature
        $parts = [];
        foreach (explode(',', $header) as $piece) {
            [$k, $v] = array_pad(explode('=', trim($piece), 2), 2, null);
            if ($k && $v) {
                $parts[$k] = $v;
            }
        }
        $timestamp = $parts['t'] ?? null;
        $signature = $parts['te'] ?? $parts['li'] ?? null;
        if (! $timestamp || ! $signature) {
            return false;
        }

        $signedPayload = $timestamp.'.'.$payload;
        $expected = hash_hmac('sha256', $signedPayload, $secret);

        return hash_equals($expected, $signature);
    }
}
