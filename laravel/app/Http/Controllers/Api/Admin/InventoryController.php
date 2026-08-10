<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\InventoryItem;
use Illuminate\Http\Request;

class InventoryController extends Controller
{
    public function index(Request $request)
    {
        $items = InventoryItem::query()
            ->with('category')
            ->whereNull('archived_at')
            ->when($request->status && $request->status !== 'all', fn ($q) => $q->where('status', $request->status))
            ->when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%"))
            ->orderBy('name')
            ->get()
            ->map(fn (InventoryItem $item) => [
                'id' => $item->id,
                'name' => $item->name,
                'category' => $item->category?->name ?? 'Uncategorized',
                'unit' => $item->unit,
                'quantity_on_hand' => $item->quantity_on_hand,
                'min_stock_level' => $item->min_stock_level,
                'status' => $item->status,
                'expiration_date' => $item->expiration_date?->toDateString(),
                'updated_at' => $item->updated_at?->toIso8601String(),
            ]);

        return response()->json(['data' => $items]);
    }
}
