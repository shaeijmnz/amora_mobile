<?php

namespace App\Services;

use App\Models\Delivery;
use App\Models\InventoryItem;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderPaymentService
{
    /**
     * Mark order paid, deduct stock once, and create a delivery row.
     */
    public function markPaid(Order $order, ?string $paymentId = null): Order
    {
        return DB::transaction(function () use ($order, $paymentId) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($order->payment_status === 'paid') {
                return $order->load(['items.product', 'items.size', 'delivery']);
            }

            $order->load(['items.product', 'items.size']);

            foreach ($order->items as $item) {
                $qty = (int) $item->quantity;
                $productName = $item->product?->name ?? 'this product';

                $inventory = InventoryItem::query()
                    ->where(function ($q) use ($item) {
                        $q->where('product_id', $item->product_id);
                        if ($item->product?->name) {
                            $q->orWhere('name', $item->product->name);
                        }
                    })
                    ->lockForUpdate()
                    ->first();

                if ($inventory) {
                    if ($inventory->quantity_on_hand < $qty) {
                        throw ValidationException::withMessages([
                            'items' => "Not enough stock for {$productName}. Only {$inventory->quantity_on_hand} left.",
                        ]);
                    }
                    $inventory->quantity_on_hand -= $qty;
                    $inventory->syncStockStatus();
                    $inventory->save();
                }
            }

            $order->update([
                'payment_status' => 'paid',
                'status' => 'confirmed',
                'payment_method' => $order->payment_method ?: 'paymongo',
                'paymongo_payment_id' => $paymentId ?: $order->paymongo_payment_id,
                'paid_at' => now(),
            ]);

            Delivery::query()->firstOrCreate(
                ['order_id' => $order->id],
                [
                    'status' => 'unscheduled',
                    'delivery_instructions' => $order->delivery_notes,
                    'attempts' => [],
                ]
            );

            return $order->fresh()->load(['items.product', 'items.size', 'delivery']);
        });
    }
}
