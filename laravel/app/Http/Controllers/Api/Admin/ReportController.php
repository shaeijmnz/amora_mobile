<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\InventoryItem;
use App\Models\InventoryMovement;
use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    /**
     * Everything the Reports page renders, in one round trip so the four tabs
     * stay consistent with each other.
     */
    public function index(Request $request)
    {
        [$from, $to] = $this->range($request->get('range', 'week'));

        return response()->json([
            'range' => [
                'key' => $request->get('range', 'week'),
                'from' => $from?->toDateString(),
                'to' => $to->toDateString(),
            ],
            'sales' => $this->sales($from, $to),
            'inventory' => $this->inventory(),
            'delivery' => $this->delivery($from, $to),
            'movements' => $this->movements($from, $to),
        ]);
    }

    /** @return array{0: ?Carbon, 1: Carbon} */
    private function range(string $key): array
    {
        $to = now()->endOfDay();

        return match ($key) {
            'today' => [now()->startOfDay(), $to],
            'month' => [now()->startOfDay()->subDays(29), $to],
            'all' => [null, $to],
            default => [now()->startOfDay()->subDays(6), $to],
        };
    }

    private function paidOrders(?Carbon $from, Carbon $to)
    {
        return Order::query()
            ->where('payment_status', 'paid')
            ->when($from, fn ($q) => $q->where('paid_at', '>=', $from))
            ->where('paid_at', '<=', $to);
    }

    private function sales(?Carbon $from, Carbon $to): array
    {
        $orders = $this->paidOrders($from, $to)->get();

        // Walk the calendar so quiet days still show as zero on the chart.
        $start = $from ?? ($orders->min('paid_at') ?? now()->startOfDay());
        $start = Carbon::parse($start)->startOfDay();
        $days = min(90, (int) $start->diffInDays($to->copy()->startOfDay()) + 1);

        $byDay = $orders->groupBy(fn (Order $o) => $o->paid_at->toDateString());

        $daily = [];
        for ($i = 0; $i < $days; $i++) {
            $day = $start->copy()->addDays($i);
            $bucket = $byDay->get($day->toDateString(), collect());
            $daily[] = [
                'date' => $day->format('M j'),
                'full_date' => $day->toDateString(),
                'revenue' => round((float) $bucket->sum('total'), 2),
                'orders' => $bucket->count(),
            ];
        }

        $orderIds = $orders->pluck('id');

        $topProducts = DB::table('order_items')
            ->join('products', 'products.id', '=', 'order_items.product_id')
            ->whereIn('order_items.order_id', $orderIds)
            ->select(
                'products.name',
                DB::raw('SUM(order_items.quantity) as orders'),
                DB::raw('SUM(order_items.quantity * order_items.unit_price) as revenue')
            )
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('revenue')
            ->limit(10)
            ->get()
            ->map(fn ($row) => [
                'name' => $row->name,
                'orders' => (int) $row->orders,
                'revenue' => round((float) $row->revenue, 2),
            ]);

        $byCategory = DB::table('order_items')
            ->join('products', 'products.id', '=', 'order_items.product_id')
            ->whereIn('order_items.order_id', $orderIds)
            ->select('products.category', DB::raw('SUM(order_items.quantity) as orders'))
            ->groupBy('products.category')
            ->orderByDesc('orders')
            ->get()
            ->map(fn ($row) => [
                'category' => $this->prettyCategory($row->category),
                'orders' => (int) $row->orders,
            ]);

        $count = $orders->count();
        $revenue = (float) $orders->sum('total');

        return [
            'daily' => $daily,
            'top_products' => $topProducts,
            'by_category' => $byCategory,
            'totals' => [
                'orders' => $count,
                'revenue' => round($revenue, 2),
                'average_order' => $count > 0 ? round($revenue / $count, 2) : 0.0,
                'items_sold' => (int) DB::table('order_items')->whereIn('order_id', $orderIds)->sum('quantity'),
            ],
        ];
    }

    private function inventory(): array
    {
        $items = InventoryItem::query()
            ->with('category')
            ->whereNull('archived_at')
            ->orderBy('name')
            ->get();

        return [
            'items' => $items->map(fn (InventoryItem $i) => [
                'id' => $i->id,
                'name' => $i->name,
                'category' => $i->category?->name ?? 'Uncategorized',
                'qty' => (int) $i->quantity_on_hand,
                'unit' => $i->unit,
                'min_stock_level' => (int) $i->min_stock_level,
                'status' => $i->status,
                'expiration_date' => $i->expiration_date?->toDateString(),
            ])->values(),
            'totals' => [
                'items' => $items->count(),
                'stems_on_hand' => (int) $items->sum('quantity_on_hand'),
                'low_stock' => $items->where('status', 'low_stock')->count(),
                'out_of_stock' => $items->where('status', 'out_of_stock')->count(),
            ],
        ];
    }

    private function delivery(?Carbon $from, Carbon $to): array
    {
        $deliveries = Delivery::query()
            ->with('order')
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->where('created_at', '<=', $to)
            ->get();

        $total = $deliveries->count();
        $delivered = $deliveries->where('status', 'delivered')->count();
        $failed = $deliveries->where('status', 'delivery_failed')->count();
        $rescheduled = $deliveries->where('status', 'rescheduled')->count();
        $inProgress = $total - $delivered - $failed;

        $percent = fn (int $n) => $total > 0 ? (int) round($n / $total * 100) : 0;

        // Measured from payment to the successful attempt.
        $durations = $deliveries
            ->filter(fn (Delivery $d) => $d->status === 'delivered' && $d->order?->paid_at)
            ->map(function (Delivery $d) {
                $done = collect($d->attempts ?? [])
                    ->firstWhere('status', 'delivered')['attempted_at'] ?? null;
                if (! $done) {
                    return null;
                }

                return $d->order->paid_at->diffInMinutes(Carbon::parse($done));
            })
            ->filter()
            ->values();

        $onTime = $deliveries
            ->filter(fn (Delivery $d) => $d->status === 'delivered' && $d->scheduled_date)
            ->filter(function (Delivery $d) {
                $done = collect($d->attempts ?? [])
                    ->firstWhere('status', 'delivered')['attempted_at'] ?? null;

                return $done && Carbon::parse($done)->startOfDay()->lte($d->scheduled_date->startOfDay());
            })
            ->count();

        return [
            'stats' => [
                ['status' => 'Delivered', 'count' => $delivered, 'percent' => $percent($delivered)],
                ['status' => 'In Progress', 'count' => $inProgress, 'percent' => $percent($inProgress)],
                ['status' => 'Failed', 'count' => $failed, 'percent' => $percent($failed)],
            ],
            'summary' => [
                'total_deliveries' => $total,
                'on_time_rate' => $delivered > 0 ? (int) round($onTime / $delivered * 100) : 0,
                'avg_delivery_minutes' => $durations->isNotEmpty() ? (int) round($durations->avg()) : null,
                'failed_deliveries' => $failed,
                'rescheduled' => $rescheduled,
                'unassigned' => $deliveries->whereNull('assigned_rider')->count(),
                'delivery_revenue' => round((float) $deliveries->sum(fn (Delivery $d) => (float) ($d->order?->delivery_fee ?? 0)), 2),
            ],
            'by_rider' => $deliveries
                ->filter(fn (Delivery $d) => filled($d->assigned_rider))
                ->groupBy('assigned_rider')
                ->map(fn ($group, $rider) => [
                    'rider' => $rider,
                    'assigned' => $group->count(),
                    'delivered' => $group->where('status', 'delivered')->count(),
                    'failed' => $group->where('status', 'delivery_failed')->count(),
                ])
                ->values(),
        ];
    }

    private function movements(?Carbon $from, Carbon $to): array
    {
        return InventoryMovement::query()
            ->when($from, fn ($q) => $q->where('created_at', '>=', $from))
            ->where('created_at', '<=', $to)
            ->latest()
            ->limit(300)
            ->get()
            ->map(fn (InventoryMovement $m) => [
                'id' => $m->id,
                'date' => $m->created_at?->format('M j, Y g:i A'),
                'item' => $m->item_name,
                'type' => $m->type,
                'qty' => ($m->quantity > 0 ? '+' : '').$m->quantity,
                'prev' => $m->previous_qty,
                'new' => $m->new_qty,
                'reason' => $m->reason,
                'ref' => $m->order_number,
                'by' => $m->performed_by ?? 'System',
            ])
            ->values()
            ->all();
    }

    private function prettyCategory(?string $raw): string
    {
        if (blank($raw)) {
            return 'Uncategorized';
        }

        return ucwords(str_replace(['_', '-'], ' ', $raw));
    }
}
