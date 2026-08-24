<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Order;
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
        ]);

        $order->update($data);
        $order->load(['customer', 'items.product', 'items.size', 'delivery']);

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
