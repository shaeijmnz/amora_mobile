<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function summary()
    {
        $today = now()->toDateString();

        return response()->json([
            'summary' => [
                'total_products' => Product::whereNull('archived_at')->count(),
                'available_flowers' => InventoryItem::whereNull('archived_at')->sum('quantity_on_hand'),
                'low_stock' => InventoryItem::whereNull('archived_at')->where('status', 'low_stock')->count(),
                'out_of_stock' => InventoryItem::whereNull('archived_at')->where('status', 'out_of_stock')->count(),
                'damaged_spoiled' => InventoryItem::whereNull('archived_at')->whereIn('status', ['damaged', 'spoiled'])->count(),
                'new_orders' => Order::where('status', 'pending')->count(),
                'being_prepared' => Order::where('status', 'being_prepared')->count(),
                'for_delivery' => Order::whereIn('status', ['ready_for_delivery', 'dispatched'])->count(),
                'completed_today' => Order::whereDate('updated_at', $today)->whereIn('status', ['completed', 'delivered'])->count(),
                'todays_sales' => (float) Order::whereDate('created_at', $today)->whereNotIn('status', ['cancelled', 'refunded'])->sum('total'),
            ],
            'recent_orders' => Order::with('customer')->latest()->limit(8)->get()->map(fn (Order $o) => [
                'id' => $o->id,
                'order_number' => $o->order_number,
                'customer_name' => $o->customer?->name,
                'total' => (float) $o->total,
                'status' => $o->status,
                'created_at' => $o->created_at?->toIso8601String(),
            ]),
            'low_stock' => InventoryItem::whereNull('archived_at')
                ->where(function ($q) {
                    $q->where('status', 'low_stock')
                        ->orWhereColumn('quantity_on_hand', '<=', 'min_stock_level');
                })
                ->orderBy('quantity_on_hand')
                ->limit(8)
                ->get()
                ->map(fn (InventoryItem $i) => [
                    'id' => $i->id,
                    'name' => $i->name,
                    'quantity_on_hand' => $i->quantity_on_hand,
                    'status' => $i->status,
                ]),
            'best_sellers' => DB::table('order_items')
                ->join('products', 'products.id', '=', 'order_items.product_id')
                ->select('products.name', DB::raw('SUM(order_items.quantity) as sold'))
                ->groupBy('products.id', 'products.name')
                ->orderByDesc('sold')
                ->limit(5)
                ->get(),
            'customers_count' => User::where('role', 'customer')->count(),
        ]);
    }
}
