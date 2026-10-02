<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Services\AdminNotifier;
use Illuminate\Http\Request;

class DeliveryController extends Controller
{
    public function index(Request $request)
    {
        $deliveries = Delivery::query()
            ->with(['order.customer', 'order.items.product'])
            ->when(
                $request->status && $request->status !== 'all',
                fn ($q) => $q->where('status', $request->status)
            )
            ->latest()
            ->get()
            ->map(fn (Delivery $d) => $this->payload($d));

        return response()->json(['data' => $deliveries]);
    }

    public function show(Delivery $delivery)
    {
        $delivery->load(['order.customer', 'order.items.product']);

        return response()->json(['data' => $this->payload($delivery)]);
    }

    public function update(Request $request, Delivery $delivery)
    {
        $data = $request->validate([
            'status' => ['sometimes', 'string'],
            'assigned_rider' => ['sometimes', 'nullable', 'string', 'max:120'],
            'scheduled_date' => ['sometimes', 'nullable', 'date'],
            'scheduled_time' => ['sometimes', 'nullable', 'string', 'max:20'],
            'delivery_instructions' => ['sometimes', 'nullable', 'string', 'max:500'],
            'failed_reason' => ['sometimes', 'nullable', 'string', 'max:500'],
            'proof_of_delivery_url' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        if (($data['status'] ?? null) === 'delivery_failed' && empty($data['failed_reason']) && empty($delivery->failed_reason)) {
            return response()->json(['message' => 'Failed reason is required.'], 422);
        }

        if (($data['status'] ?? null) === 'delivery_failed') {
            $attempts = $delivery->attempts ?? [];
            $attempts[] = [
                'number' => count($attempts) + 1,
                'status' => 'failed',
                'failed_reason' => $data['failed_reason'] ?? $delivery->failed_reason,
                'attempted_at' => now()->toIso8601String(),
            ];
            $data['attempts'] = $attempts;
        }

        if (($data['status'] ?? null) === 'delivered') {
            $attempts = $delivery->attempts ?? [];
            $attempts[] = [
                'number' => count($attempts) + 1,
                'status' => 'delivered',
                'failed_reason' => null,
                'attempted_at' => now()->toIso8601String(),
            ];
            $data['attempts'] = $attempts;

            $delivery->order?->update(['status' => 'delivered']);
        }

        if (($data['status'] ?? null) === 'out_for_delivery' || ($data['status'] ?? null) === 'dispatched') {
            $delivery->order?->update(['status' => 'dispatched']);
        }

        $statusChanged = isset($data['status']) && $data['status'] !== $delivery->status;

        $delivery->update($data);
        $delivery->load(['order.customer', 'order.items.product']);

        if ($statusChanged) {
            app(AdminNotifier::class)->deliveryStatusChanged($delivery, $data['status']);
        }

        return response()->json([
            'message' => 'Delivery updated.',
            'data' => $this->payload($delivery),
        ]);
    }

    private function payload(Delivery $delivery): array
    {
        $order = $delivery->order;

        return [
            'id' => $delivery->id,
            'order_id' => $delivery->order_id,
            'order_number' => $order?->order_number,
            'recipient' => $order?->recipient_name,
            'recipient_contact' => $order?->recipient_contact,
            'address' => $order?->delivery_address,
            'delivery_fee' => (float) ($order?->delivery_fee ?? 0),
            'delivery_instructions' => $delivery->delivery_instructions ?: $order?->delivery_notes,
            'status' => $delivery->status,
            'assigned_rider' => $delivery->assigned_rider,
            'scheduled_date' => $delivery->scheduled_date?->format('Y-m-d'),
            'scheduled_time' => $delivery->scheduled_time,
            'requested_date' => $order?->requested_delivery_date?->format('Y-m-d'),
            'requested_time' => $order?->requested_delivery_time,
            'failed_reason' => $delivery->failed_reason,
            'proof_of_delivery_url' => $delivery->proof_of_delivery_url,
            'attempts' => $delivery->attempts ?? [],
            'payment_status' => $order?->payment_status,
            'order_status' => $order?->status,
            'created_at' => $delivery->created_at?->toIso8601String(),
        ];
    }
}
