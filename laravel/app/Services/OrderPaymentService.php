<?php

namespace App\Services;

use App\Models\Delivery;
use App\Models\InventoryItem;
use App\Models\InventoryMovement;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderPaymentService
{
    public function __construct(private AdminNotifier $notifier) {}

    /**
     * Mark order paid, deduct stock once, and create a delivery row.
     */
    public function markPaid(Order $order, ?string $paymentId = null): Order
    {
        /** @var array{order: Order, fresh: bool, depleted: array<int, InventoryItem>} $result */
        $result = DB::transaction(function () use ($order, $paymentId) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($order->payment_status === 'paid') {
                return [
                    'order' => $order->load(['items.product', 'items.size', 'delivery']),
                    'fresh' => false,
                    'depleted' => [],
                ];
            }

            $order->load(['items.product', 'items.size']);
            $depleted = [];

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

                    $previous = (int) $inventory->quantity_on_hand;
                    $inventory->quantity_on_hand = $previous - $qty;
                    $inventory->syncStockStatus();
                    $inventory->save();

                    InventoryMovement::create([
                        'inventory_item_id' => $inventory->id,
                        'item_name' => $inventory->name,
                        'type' => 'stock_out',
                        'quantity' => -$qty,
                        'previous_qty' => $previous,
                        'new_qty' => (int) $inventory->quantity_on_hand,
                        'reason' => 'Sold via mobile checkout',
                        'order_id' => $order->id,
                        'order_number' => $order->order_number,
                        'performed_by' => 'System',
                    ]);

                    if (in_array($inventory->status, ['low_stock', 'out_of_stock'], true)) {
                        $depleted[] = $inventory;
                    }
                }
            }

            $order->update([
                'payment_status' => 'paid',
                'status' => 'confirmed',
                'payment_method' => $order->payment_method ?: 'paymongo',
                'paymongo_payment_id' => $paymentId ?: $order->paymongo_payment_id,
                'paid_at' => now(),
            ]);

            // Customer already picked the slot at checkout, so the owner only
            // has to assign a rider and move the parcel status.
            Delivery::query()->firstOrCreate(
                ['order_id' => $order->id],
                [
                    'status' => $order->requested_delivery_date ? 'scheduled' : 'unscheduled',
                    'scheduled_date' => $order->requested_delivery_date,
                    'scheduled_time' => $order->requested_delivery_time,
                    'delivery_instructions' => $order->delivery_notes,
                    'attempts' => [],
                ]
            );

            return [
                'order' => $order->fresh()->load(['items.product', 'items.size', 'delivery']),
                'fresh' => true,
                'depleted' => $depleted,
            ];
        });

        // Raised outside the transaction so a notification failure can never
        // roll back a payment that PayMongo already took.
        if ($result['fresh']) {
            $this->notifier->orderPaid($result['order']);
            foreach ($result['depleted'] as $item) {
                $this->notifier->lowStock($item);
            }
        }

        return $result['order'];
    }
}
