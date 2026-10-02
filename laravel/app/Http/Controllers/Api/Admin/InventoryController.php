<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\InventoryItem;
use App\Models\InventoryMovement;
use App\Services\AdminNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryController extends Controller
{
    public function __construct(private AdminNotifier $notifier) {}

    public function index(Request $request)
    {
        $items = InventoryItem::query()
            ->with('category')
            ->whereNull('archived_at')
            ->when($request->status && $request->status !== 'all', fn ($q) => $q->where('status', $request->status))
            ->when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%"))
            ->orderBy('name')
            ->get()
            ->map(fn (InventoryItem $item) => $this->payload($item));

        return response()->json(['data' => $items]);
    }

    /**
     * Owner-side stock correction. Either set an absolute quantity or apply a
     * delta; both are written to the movement history so Reports can show them.
     */
    public function update(Request $request, InventoryItem $item)
    {
        $data = $request->validate([
            'quantity_on_hand' => ['sometimes', 'integer', 'min:0'],
            'adjustment' => ['sometimes', 'integer'],
            'min_stock_level' => ['sometimes', 'integer', 'min:0'],
            'type' => ['sometimes', 'string', 'in:stock_in,stock_out,adjustment,damaged,spoiled,reserved_release'],
            'reason' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        if (! array_key_exists('quantity_on_hand', $data) && ! array_key_exists('adjustment', $data) && ! array_key_exists('min_stock_level', $data)) {
            return response()->json(['message' => 'Nothing to update.'], 422);
        }

        $item = DB::transaction(function () use ($data, $item, $request) {
            $item = InventoryItem::query()->lockForUpdate()->findOrFail($item->id);
            $previous = (int) $item->quantity_on_hand;

            $next = $previous;
            if (array_key_exists('quantity_on_hand', $data)) {
                $next = (int) $data['quantity_on_hand'];
            } elseif (array_key_exists('adjustment', $data)) {
                $next = max(0, $previous + (int) $data['adjustment']);
            }

            if (array_key_exists('min_stock_level', $data)) {
                $item->min_stock_level = (int) $data['min_stock_level'];
            }

            $item->quantity_on_hand = $next;
            $item->syncStockStatus();
            $item->save();

            $delta = $next - $previous;
            if ($delta !== 0) {
                InventoryMovement::create([
                    'inventory_item_id' => $item->id,
                    'item_name' => $item->name,
                    'type' => $data['type'] ?? ($delta > 0 ? 'stock_in' : 'adjustment'),
                    'quantity' => $delta,
                    'previous_qty' => $previous,
                    'new_qty' => $next,
                    'reason' => $data['reason'] ?? 'Manual stock update',
                    'performed_by' => $request->user()?->name ?? 'Admin',
                ]);
            }

            return $item;
        });

        // Always called: it raises the alert when low and clears it when restocked.
        $this->notifier->lowStock($item);

        return response()->json([
            'message' => 'Inventory updated.',
            'data' => $this->payload($item->fresh()->load('category')),
        ]);
    }

    private function payload(InventoryItem $item): array
    {
        return [
            'id' => $item->id,
            'name' => $item->name,
            'category' => $item->category?->name ?? 'Uncategorized',
            'unit' => $item->unit,
            'quantity_on_hand' => (int) $item->quantity_on_hand,
            'min_stock_level' => (int) $item->min_stock_level,
            'status' => $item->status,
            'expiration_date' => $item->expiration_date?->toDateString(),
            'updated_at' => $item->updated_at?->toIso8601String(),
        ];
    }
}
