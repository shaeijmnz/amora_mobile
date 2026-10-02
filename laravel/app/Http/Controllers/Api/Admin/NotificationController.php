<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminNotification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $notifications = AdminNotification::query()
            ->when(
                $request->category && $request->category !== 'all',
                fn ($q) => $q->where('category', $request->category)
            )
            ->latest()
            ->limit(200)
            ->get()
            ->map(fn (AdminNotification $n) => [
                'id' => $n->id,
                'category' => $n->category,
                'title' => $n->title,
                'body' => $n->body,
                'order_id' => $n->order_id,
                'inventory_item_id' => $n->inventory_item_id,
                'is_read' => $n->is_read,
                'created_at' => $n->created_at?->toIso8601String(),
            ]);

        return response()->json([
            'data' => $notifications,
            'unread_count' => AdminNotification::where('is_read', false)->count(),
        ]);
    }

    public function unreadCount()
    {
        return response()->json([
            'unread_count' => AdminNotification::where('is_read', false)->count(),
        ]);
    }

    public function markRead(AdminNotification $notification)
    {
        $notification->update(['is_read' => true, 'read_at' => now()]);

        return response()->json([
            'message' => 'Notification marked as read.',
            'unread_count' => AdminNotification::where('is_read', false)->count(),
        ]);
    }

    public function markAllRead()
    {
        AdminNotification::where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return response()->json(['message' => 'All notifications marked as read.', 'unread_count' => 0]);
    }

    public function destroy(AdminNotification $notification)
    {
        $notification->delete();

        return response()->json([
            'message' => 'Notification dismissed.',
            'unread_count' => AdminNotification::where('is_read', false)->count(),
        ]);
    }
}
