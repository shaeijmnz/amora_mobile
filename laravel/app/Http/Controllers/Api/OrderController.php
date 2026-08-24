<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\ProductSize;
use App\Services\OrderPaymentService;
use App\Services\PayMongoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $orders = Order::query()
            ->where('customer_id', $request->user()->id)
            ->with(['items.product', 'items.size', 'delivery'])
            ->latest()
            ->get()
            ->map(fn (Order $order) => $this->orderPayload($order));

        return response()->json(['data' => $orders]);
    }

    /**
     * Legacy COD-style place order (kept for compatibility). Prefer checkout().
     */
    public function store(Request $request)
    {
        return $this->checkout($request);
    }

    /**
     * Create awaiting_payment order + PayMongo hosted checkout session.
     * Stock is NOT deducted until payment succeeds.
     */
    public function checkout(Request $request, PayMongoService $paymongo)
    {
        $data = $request->validate([
            'recipient_name' => ['required', 'string', 'max:120'],
            'recipient_contact' => ['required', 'string', 'max:40'],
            'delivery_address' => ['required', 'string', 'max:500'],
            'delivery_notes' => ['nullable', 'string', 'max:500'],
            'delivery_fee' => ['nullable', 'numeric', 'min:0'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.size_id' => ['required', 'integer', 'exists:product_sizes,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.flower_color' => ['nullable', 'string', 'max:60'],
            'items.*.personalized_message' => ['nullable', 'string', 'max:500'],
        ]);

        try {
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
                    'payment_status' => 'awaiting_payment',
                    'payment_method' => 'paymongo',
                    'subtotal' => $subtotal,
                    'delivery_fee' => $deliveryFee,
                    'discount' => 0,
                    'total' => $total,
                    'recipient_name' => $data['recipient_name'],
                    'recipient_contact' => $data['recipient_contact'],
                    'delivery_address' => $data['delivery_address'],
                    'delivery_notes' => $data['delivery_notes'] ?? null,
                ]);

                $order->items()->createMany($lineItems);

                return $order->load(['items.product', 'items.size']);
            });
        } catch (ValidationException $e) {
            throw $e;
        }

        $successUrl = rtrim((string) config('services.paymongo.success_url'), '/');
        $cancelUrl = rtrim((string) config('services.paymongo.cancel_url'), '/');
        $successUrl .= (str_contains($successUrl, '?') ? '&' : '?').'order_id='.$order->id;
        $cancelUrl .= (str_contains($cancelUrl, '?') ? '&' : '?').'order_id='.$order->id;

        $paymongoLines = [];
        foreach ($order->items as $item) {
            $name = $item->product?->name ?? 'Bloom';
            if ($item->size?->label) {
                $name .= ' ('.$item->size->label.')';
            }
            $paymongoLines[] = [
                'name' => $name,
                'amount' => (int) round(((float) $item->unit_price) * 100),
                'currency' => 'PHP',
                'quantity' => (int) $item->quantity,
            ];
        }
        if ((float) $order->delivery_fee > 0) {
            $paymongoLines[] = [
                'name' => 'Delivery fee',
                'amount' => (int) round(((float) $order->delivery_fee) * 100),
                'currency' => 'PHP',
                'quantity' => 1,
            ];
        }

        try {
            $session = $paymongo->createCheckoutSession([
                'send_email_receipt' => false,
                'show_description' => true,
                'show_line_items' => true,
                'description' => 'Amora Florals '.$order->order_number,
                'line_items' => $paymongoLines,
                'payment_method_types' => ['qrph'],
                'success_url' => $successUrl,
                'cancel_url' => $cancelUrl,
                'reference_number' => $order->order_number,
                'metadata' => [
                    'order_id' => (string) $order->id,
                    'order_number' => $order->order_number,
                ],
            ]);
        } catch (RuntimeException $e) {
            $order->update([
                'status' => 'cancelled',
                'payment_status' => 'unpaid',
            ]);

            return response()->json(['message' => $e->getMessage()], 422);
        }

        $order->update(['paymongo_checkout_id' => $session['id']]);

        return response()->json([
            'message' => 'Checkout created. Complete payment on PayMongo.',
            'data' => array_merge($this->orderPayload($order->fresh()->load(['items.product', 'items.size'])), [
                'checkout_url' => $session['checkout_url'],
                'paymongo_checkout_id' => $session['id'],
            ]),
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

    /**
     * Poll / verify payment after PayMongo redirect (works without webhook).
     */
    public function paymentStatus(
        Request $request,
        Order $order,
        PayMongoService $paymongo,
        OrderPaymentService $payments,
    ) {
        if ($order->customer_id !== $request->user()->id) {
            return response()->json(['message' => 'Order not found.'], 404);
        }

        if ($order->payment_status !== 'paid' && $order->paymongo_checkout_id) {
            try {
                $session = $paymongo->retrieveCheckoutSession($order->paymongo_checkout_id);
                if ($paymongo->checkoutSessionIsPaid($session)) {
                    $order = $payments->markPaid($order, $paymongo->firstPaymentId($session));
                }
            } catch (RuntimeException $e) {
                // Keep current status; client can retry.
            } catch (ValidationException $e) {
                return response()->json([
                    'message' => $e->getMessage(),
                    'errors' => $e->errors(),
                    'data' => $this->orderPayload($order->fresh()->load(['items.product', 'items.size'])),
                ], 422);
            }
        }

        $order->load(['items.product', 'items.size']);

        return response()->json([
            'data' => $this->orderPayload($order),
            'paid' => $order->payment_status === 'paid',
        ]);
    }

    private function orderPayload(Order $order): array
    {
        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'payment_method' => $order->payment_method,
            'paymongo_checkout_id' => $order->paymongo_checkout_id,
            'paid_at' => $order->paid_at?->toIso8601String(),
            'subtotal' => (float) $order->subtotal,
            'delivery_fee' => (float) $order->delivery_fee,
            'discount' => (float) $order->discount,
            'total' => (float) $order->total,
            'recipient_name' => $order->recipient_name,
            'recipient_contact' => $order->recipient_contact,
            'delivery_address' => $order->delivery_address,
            'delivery_notes' => $order->delivery_notes,
            'delivery_status' => $order->delivery?->status,
            'assigned_rider' => $order->delivery?->assigned_rider,
            'scheduled_date' => $order->delivery?->scheduled_date?->format('Y-m-d'),
            'scheduled_time' => $order->delivery?->scheduled_time,
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
