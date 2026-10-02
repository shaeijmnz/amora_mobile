<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Services\AdminNotifier;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        // Default: only paid orders appear in admin ops.
        $paymentStatus = $request->get('payment_status', 'paid');

        $orders = Order::query()
            ->with(['customer', 'items.product', 'items.size', 'delivery'])
            ->when(
                $paymentStatus && $paymentStatus !== 'all',
                fn ($q) => $q->where('payment_status', $paymentStatus)
            )
            ->when($request->status && $request->status !== 'all', fn ($q) => $q->where('status', $request->status))
            ->latest()
            ->get()
            ->map(fn (Order $o) => $this->payload($o));

        return response()->json(['data' => $orders]);
    }

    public function show(Order $order)
    {
        $order->load(['customer', 'items.product', 'items.size', 'delivery']);

        return response()->json(['data' => $this->payload($order)]);
    }

    public function updateStatus(Request $request, Order $order)
    {
        $data = $request->validate([
            'status' => ['sometimes', 'string'],
            'payment_status' => ['sometimes', 'string'],
            'admin_notes' => ['sometimes', 'nullable', 'string'],
            'delivery_status' => ['sometimes', 'string'],
            'assigned_rider' => ['sometimes', 'nullable', 'string', 'max:120'],
            'failed_reason' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $deliveryStatus = $data['delivery_status'] ?? null;
        $rider = array_key_exists('assigned_rider', $data) ? $data['assigned_rider'] : null;
        $failedReason = $data['failed_reason'] ?? null;
        unset($data['delivery_status'], $data['assigned_rider'], $data['failed_reason']);

        if ($deliveryStatus === 'delivery_failed' && blank($failedReason) && blank($order->delivery?->failed_reason)) {
            return response()->json(['message' => 'Failed reason is required.'], 422);
        }

        if ($data !== []) {
            $order->update($data);
        }

        if ($deliveryStatus !== null || $request->has('assigned_rider') || $failedReason !== null) {
            $delivery = $order->delivery ?? Delivery::create([
                'order_id' => $order->id,
                'status' => $order->requested_delivery_date ? 'scheduled' : 'unscheduled',
                'scheduled_date' => $order->requested_delivery_date,
                'scheduled_time' => $order->requested_delivery_time,
                'delivery_instructions' => $order->delivery_notes,
                'attempts' => [],
            ]);

            $deliveryUpdate = [];
            if ($deliveryStatus !== null) {
                $deliveryUpdate['status'] = $deliveryStatus;
            }
            if ($request->has('assigned_rider')) {
                $deliveryUpdate['assigned_rider'] = $rider;
            }
            if ($failedReason !== null) {
                $deliveryUpdate['failed_reason'] = $failedReason;
            }

            if (in_array($deliveryStatus, ['delivered', 'delivery_failed'], true)) {
                $attempts = $delivery->attempts ?? [];
                $attempts[] = [
                    'number' => count($attempts) + 1,
                    'status' => $deliveryStatus === 'delivered' ? 'delivered' : 'failed',
                    'failed_reason' => $deliveryStatus === 'delivered' ? null : ($failedReason ?: $delivery->failed_reason),
                    'attempted_at' => now()->toIso8601String(),
                ];
                $deliveryUpdate['attempts'] = $attempts;
            }

            $statusChanged = $deliveryStatus !== null && $deliveryStatus !== $delivery->getOriginal('status');

            $delivery->update($deliveryUpdate);

            if ($statusChanged) {
                app(AdminNotifier::class)->deliveryStatusChanged($delivery, $deliveryStatus);
            }

            // Keep the buyer-facing order status aligned with the parcel.
            $mirror = match ($deliveryStatus) {
                'delivered' => 'delivered',
                'dispatched', 'out_for_delivery' => 'dispatched',
                'preparing_for_dispatch' => 'being_prepared',
                default => null,
            };
            if ($mirror && ! $request->has('status')) {
                $order->update(['status' => $mirror]);
            }
        }

        $order->refresh()->load(['customer', 'items.product', 'items.size', 'delivery']);

        return response()->json([
            'message' => 'Order updated.',
            'data' => $this->payload($order),
        ]);
    }

    private function payload(Order $order): array
    {
        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'customer_name' => $order->customer?->name,
            'customer_email' => $order->customer?->email,
            'customer_phone' => $order->customer?->phone,
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'payment_method' => $order->payment_method,
            'paid_at' => $order->paid_at?->toIso8601String(),
            'subtotal' => (float) $order->subtotal,
            'delivery_fee' => (float) $order->delivery_fee,
            'discount' => (float) $order->discount,
            'total' => (float) $order->total,
            'recipient_name' => $order->recipient_name,
            'recipient_contact' => $order->recipient_contact,
            'delivery_address' => $order->delivery_address,
            'delivery_notes' => $order->delivery_notes,
            'admin_notes' => $order->admin_notes,
            // Slot the customer picked at checkout — the owner does not choose it.
            'requested_delivery_date' => $order->requested_delivery_date?->format('Y-m-d'),
            'requested_delivery_time' => $order->requested_delivery_time,
            'delivery_id' => $order->delivery?->id,
            'delivery_status' => $order->delivery?->status,
            'assigned_rider' => $order->delivery?->assigned_rider,
            'scheduled_date' => $order->delivery?->scheduled_date?->format('Y-m-d')
                ?? $order->requested_delivery_date?->format('Y-m-d'),
            'scheduled_time' => $order->delivery?->scheduled_time ?? $order->requested_delivery_time,
            'failed_reason' => $order->delivery?->failed_reason,
            'created_at' => $order->created_at?->toIso8601String(),
            'items' => $order->items->map(fn ($item) => [
                'id' => $item->id,
                'product_name' => $item->product?->name,
                'size_label' => $item->size?->label,
                'quantity' => $item->quantity,
                'unit_price' => (float) $item->unit_price,
            ])->values(),
        ];
    }
}
