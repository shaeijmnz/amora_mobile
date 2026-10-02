<?php

namespace App\Services;

use App\Models\AdminNotification;
use App\Models\CustomRequest;
use App\Models\Delivery;
use App\Models\InventoryItem;
use App\Models\Order;

/**
 * Single place that raises the bell-icon notifications the admin dashboard
 * polls for. Every caller goes through here so the wording stays consistent.
 */
class AdminNotifier
{
    public function orderPaid(Order $order): void
    {
        $order->loadMissing(['customer', 'items.product']);

        $blooms = $order->items
            ->map(fn ($i) => $i->quantity.'× '.($i->product?->name ?? 'bloom'))
            ->join(', ');

        $this->push(
            category: 'orders',
            title: "New paid order {$order->order_number}",
            body: trim(sprintf(
                '%s paid %s for %s. Deliver to %s on %s.',
                $order->customer?->name ?? 'A customer',
                '₱'.number_format((float) $order->total, 2),
                $blooms ?: 'their order',
                $order->recipient_name ?: 'the recipient',
                $this->slot($order) ?: 'an unscheduled date'
            )),
            orderId: $order->id,
            dedupeKey: "order_paid:{$order->id}",
        );
    }

    public function deliveryStatusChanged(Delivery $delivery, string $status): void
    {
        $delivery->loadMissing('order');
        $orderNumber = $delivery->order?->order_number ?? "#{$delivery->order_id}";
        $pretty = str_replace('_', ' ', $status);

        $body = match ($status) {
            'delivery_failed' => 'Delivery failed'.($delivery->failed_reason ? ": {$delivery->failed_reason}" : '.'),
            'delivered' => 'The bouquet was handed over to the recipient.',
            default => $delivery->assigned_rider
                ? "Parcel is now {$pretty} with {$delivery->assigned_rider}."
                : "Parcel is now {$pretty}.",
        };

        $this->push(
            category: 'deliveries',
            title: "{$orderNumber} — {$pretty}",
            body: $body,
            orderId: $delivery->order_id,
            // One entry per status change, not per save.
            dedupeKey: "delivery:{$delivery->id}:{$status}",
        );
    }

    public function lowStock(InventoryItem $item): void
    {
        if ($item->quantity_on_hand > 0 && $item->status !== 'low_stock') {
            // Restocked, so let a future dip raise a fresh alert.
            AdminNotification::whereIn('dedupe_key', [
                "stock:{$item->id}:low",
                "stock:{$item->id}:out",
            ])->delete();

            return;
        }

        $out = $item->quantity_on_hand <= 0;

        // Crossing between "low" and "out" is worth a fresh alert, so clear the
        // key for the level the item just left.
        AdminNotification::where('dedupe_key', "stock:{$item->id}:".($out ? 'low' : 'out'))->delete();

        $this->push(
            category: 'inventory',
            title: $out ? "{$item->name} is out of stock" : "{$item->name} is running low",
            body: $out
                ? "No {$item->unit} left. Restock before accepting more orders."
                : "Only {$item->quantity_on_hand} {$item->unit} left (minimum is {$item->min_stock_level}).",
            inventoryItemId: $item->id,
            // Re-notify when it crosses into a different level, not every sale.
            dedupeKey: "stock:{$item->id}:".($out ? 'out' : 'low'),
        );
    }

    public function customRequestSubmitted(CustomRequest $request): void
    {
        $request->loadMissing('customer');

        $this->push(
            category: 'custom_requests',
            title: "New custom request {$request->request_number}",
            body: sprintf(
                '%s wants a %s arrangement for %s with a budget of %s.',
                $request->customer?->name ?? 'A customer',
                $request->bouquet_size ?: 'custom',
                $request->occasion,
                '₱'.number_format((float) $request->budget, 2)
            ),
            dedupeKey: "custom_request:{$request->id}",
        );
    }

    public function system(string $title, ?string $body = null): void
    {
        $this->push(category: 'system', title: $title, body: $body);
    }

    private function push(
        string $category,
        string $title,
        ?string $body = null,
        ?int $orderId = null,
        ?int $inventoryItemId = null,
        ?string $dedupeKey = null,
    ): void {
        if ($dedupeKey && AdminNotification::where('dedupe_key', $dedupeKey)->exists()) {
            return;
        }

        AdminNotification::create([
            'category' => $category,
            'title' => $title,
            'body' => $body,
            'order_id' => $orderId,
            'inventory_item_id' => $inventoryItemId,
            'dedupe_key' => $dedupeKey,
            'is_read' => false,
        ]);
    }

    private function slot(Order $order): ?string
    {
        $date = $order->requested_delivery_date;
        if (! $date) {
            return null;
        }

        return $date->format('M j').($order->requested_delivery_time ? ' '.$order->requested_delivery_time : '');
    }
}
