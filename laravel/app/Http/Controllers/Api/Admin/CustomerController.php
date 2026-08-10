<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $customers = User::query()
            ->where('role', 'customer')
            ->withCount('orders')
            ->withSum('orders as total_spent', 'total')
            ->when($request->search, function ($q, $search) {
                $q->where(function ($inner) use ($search) {
                    $inner->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->get()
            ->map(fn (User $u) => [
                'id' => (string) $u->id,
                'name' => $u->name,
                'email' => $u->email,
                'phone' => $u->phone,
                'total_orders' => $u->orders_count,
                'total_spent' => (float) ($u->total_spent ?? 0),
                'last_order_date' => optional($u->orders()->latest()->first())->created_at?->toDateString(),
                'account_status' => $u->email_verified_at ? 'active' : 'inactive',
                'joined' => $u->created_at?->toDateString(),
                'email_verified' => (bool) $u->email_verified_at,
            ]);

        return response()->json(['data' => $customers]);
    }

    public function show(User $user)
    {
        if ($user->role !== 'customer') {
            return response()->json(['message' => 'Not a customer.'], 404);
        }

        $orders = $user->orders()->latest()->limit(20)->get()->map(fn ($o) => [
            'order_number' => $o->order_number,
            'total' => (float) $o->total,
            'status' => $o->status,
            'date' => $o->created_at?->toDateString(),
        ]);

        return response()->json([
            'data' => [
                'id' => (string) $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'total_orders' => $user->orders()->count(),
                'total_spent' => (float) $user->orders()->sum('total'),
                'account_status' => $user->email_verified_at ? 'active' : 'inactive',
                'joined' => $user->created_at?->toDateString(),
                'orders' => $orders,
                'addresses' => [],
                'notes' => [],
            ],
        ]);
    }
}
