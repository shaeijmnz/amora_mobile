<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationMessage;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class MessageController extends Controller
{
    public function index()
    {
        $conversations = Conversation::query()
            ->with('customer')
            ->whereNotNull('last_message_at')
            ->orderByDesc('last_message_at')
            ->get()
            ->map(fn (Conversation $c) => $this->summary($c));

        return response()->json([
            'data' => $conversations,
            'unread_count' => (int) Conversation::query()->sum('admin_unread'),
        ]);
    }

    public function unreadCount()
    {
        return response()->json([
            'unread_count' => (int) Conversation::query()->sum('admin_unread'),
        ]);
    }

    public function show(Conversation $conversation)
    {
        $conversation->load(['customer', 'messages']);
        if ($conversation->admin_unread > 0) {
            $conversation->update(['admin_unread' => 0]);
        }

        return response()->json(['data' => $this->detail($conversation)]);
    }

    public function store(Request $request, Conversation $conversation)
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:1000'],
        ]);

        $body = trim($data['body']);
        if ($body === '') {
            return response()->json(['message' => 'Write a reply first.'], 422);
        }

        $message = $conversation->messages()->create([
            'sender_role' => 'admin',
            'body' => $body,
        ]);

        $conversation->update([
            'last_body' => Str::limit($body, 180),
            'last_message_at' => $message->created_at,
            'admin_unread' => 0,
            'customer_unread' => $conversation->customer_unread + 1,
        ]);

        $conversation->load(['customer', 'messages']);

        return response()->json(['data' => $this->detail($conversation)], 201);
    }

    private function summary(Conversation $c): array
    {
        return [
            'id' => $c->id,
            'customer_name' => $c->customer?->name ?: 'Customer',
            'customer_email' => $c->customer?->email,
            'preview' => $c->last_body ?: '',
            'time' => $this->timeLabel($c->last_message_at),
            'unread' => (int) $c->admin_unread,
        ];
    }

    private function detail(Conversation $c): array
    {
        return [
            ...$this->summary($c),
            'messages' => $c->messages->sortBy('id')->values()->map(fn (ConversationMessage $m) => [
                'id' => $m->id,
                'body' => $m->body,
                'mine' => $m->sender_role === 'admin',
                'time' => $m->created_at?->timezone(config('app.timezone'))->format('g:i A') ?? '',
            ])->values(),
        ];
    }

    private function timeLabel($at): string
    {
        if (! $at) {
            return '';
        }

        if ($at->isToday()) {
            return $at->timezone(config('app.timezone'))->format('g:i A');
        }
        if ($at->isYesterday()) {
            return 'Yesterday';
        }

        return $at->timezone(config('app.timezone'))->format('M j');
    }
}
