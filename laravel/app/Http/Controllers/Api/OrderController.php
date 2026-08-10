<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\ProductSize;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $orders = Order::query()
            ->where('customer_id', $request->user()->id)
            ->with(['items.product', 'items.size'])
            ->latest()
            ->get()
            ->map(fn (Order $order) => $this->orderPayload($order));

        return response()->json(['data' => $orders]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'recipient_name' => ['required', 'string', 'max:120'],
            'recipient_contact' => ['required', 'string', 'max:40'],
            'delivery_address' => ['required', 'string', 'max:500'],
            'payment_method' => ['nullable', 'string', 'max:40'],
            'delivery_fee' => ['nullable', 'numeric', 'min:0'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.size_id' => ['required', 'integer', 'exists:product_sizes,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.flower_color' => ['nullable', 'string', 'max:60'],
            'items.*.personalized_message' => ['nullable', 'string', 'max:500'],
        ]);

        $order = DB::transaction(function () use ($request, $data) {
            $subtotal = 0;
            $lineItems = [];

            foreach ($data['items'] as $item) {
                $size = ProductSize::with('product')->findOrFail($item['size_id']);
                $qty = (int) $item['quantity'];
                $lineTotal = (float) $size->price * $qty;
                $subtotal += $lineTotal;

                $lineItems[] = [
                    'product_id' => $size->product_id,
                    'size_id' => $size->id,
                    'quantity' => $qty,
                    'unit_price' => $size->price,
                    'flower_color' => $item['flower_color'] ?? null,
                    'personalized_message' => $item['personalized_message'] ?? null,
                ];
            }

            $deliveryFee = (float) ($data['delivery_fee'] ?? 0);
            $total = $subtotal + $deliveryFee;

            $order = Order::create([
                'order_number' => 'AF-'.now()->format('ymd').'-'.Str::upper(Str::random(4)),
                'customer_id' => $request->user()->id,
                'order_type' => 'standard',
                'status' => 'pending',
                'payment_status' => 'unpaid',
                'payment_method' => $data['payment_method'] ?? 'cod',
                'subtotal' => $subtotal,
                'delivery_fee' => $deliveryFee,
                'discount' => 0,
                'total' => $total,
                'recipient_name' => $data['recipient_name'],
                'recipient_contact' => $data['recipient_contact'],
                'delivery_address' => $data['delivery_address'],
            ]);

            $order->items()->createMany($lineItems);

            return $order->load(['items.product', 'items.size']);
        });

        return response()->json([
            'message' => 'Order placed.',
            'data' => $this->orderPayload($order),
        ], 201);
    }

    public function show(Request $request, Order $order)
    {
        if ($order->customer_id !== $request->user()->id) {
            return response()->json(['message' => 'Order not found.'], 404);
        }

        $order->load(['items.product', 'items.size']);

        return response()->json(['data' => $this->orderPayload($order)]);
    }

    private function orderPayload(Order $order): array
    {
        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'payment_method' => $order->payment_method,
            'subtotal' => (float) $order->subtotal,
            'delivery_fee' => (float) $order->delivery_fee,
            'discount' => (float) $order->discount,
            'total' => (float) $order->total,
            'recipient_name' => $order->recipient_name,
            'recipient_contact' => $order->recipient_contact,
            'delivery_address' => $order->delivery_address,
            'created_at' => $order->created_at?->toIso8601String(),
            'items' => $order->items->map(fn ($item) => [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'product_name' => $item->product?->name,
                'size_id' => $item->size_id,
                'size_label' => $item->size?->label,
                'quantity' => $item->quantity,
                'unit_price' => (float) $item->unit_price,
                'flower_color' => $item->flower_color,
                'personalized_message' => $item->personalized_message,
            ])->values(),
        ];
    }
}
