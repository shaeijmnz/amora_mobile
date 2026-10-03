<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationMessage;
use App\Services\AdminNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class MessageController extends Controller
{
    public function __construct(private AdminNotifier $notifier) {}

    public function show(Request $request)
    {
        $user = $request->user();
        abort_unless($user->isCustomer(), 403, 'Only a customer account can message the shop.');

        $conversation = Conversation::query()
            ->where('customer_id', $user->id)
            ->with('messages')
            ->first();

        if ($conversation && $request->boolean('mark_read')) {
            $conversation->update(['customer_unread' => 0]);
            $conversation->refresh();
        }

        return response()->json(['data' => $this->thread($conversation)]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        abort_unless($user->isCustomer(), 403, 'Only a customer account can message the shop.');

        $data = $request->validate([
            'body' => ['required', 'string', 'max:1000'],
        ]);

        $body = trim($data['body']);
        if ($body === '') {
            return response()->json(['message' => 'Write a message first.'], 422);
        }

        $conversation = Conversation::query()->firstOrCreate(
            ['customer_id' => $user->id],
        );

        $message = $conversation->messages()->create([
            'sender_role' => 'customer',
            'body' => $body,
        ]);

        $conversation->update([
            'last_body' => Str::limit($body, 180),
            'last_message_at' => $message->created_at,
            'admin_unread' => $conversation->admin_unread + 1,
        ]);

        $this->notifier->customerMessaged($user->name ?: 'A customer', $body, $message->id);

        $conversation->load('messages');

        return response()->json(['data' => $this->thread($conversation)], 201);
    }

    private function thread(?Conversation $conversation): array
    {
        $messages = $conversation
            ? $conversation->messages->sortBy('id')->values()
            : collect();

        return [
            'id' => $conversation?->id,
            'name' => 'Admin',
            'role' => 'Amora Florals',
            'preview' => $conversation?->last_body ?: 'Ask the shop about a bouquet or an order.',
            'time' => $this->timeLabel($conversation?->last_message_at),
            'unread' => (int) ($conversation?->customer_unread ?? 0),
            'messages' => $messages->map(fn (ConversationMessage $m) => [
                'id' => $m->id,
                'body' => $m->body,
                'mine' => $m->sender_role === 'customer',
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
