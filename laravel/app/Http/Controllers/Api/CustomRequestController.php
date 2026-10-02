<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomRequest;
use App\Services\AdminNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CustomRequestController extends Controller
{
    public function __construct(private AdminNotifier $notifier) {}

    public function index(Request $request)
    {
        $requests = CustomRequest::query()
            ->where('customer_id', $request->user()->id)
            ->latest()
            ->get()
            ->map(fn (CustomRequest $r) => $this->payload($r));

        return response()->json(['data' => $requests]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'occasion' => ['required', 'string', 'max:120'],
            'preferred_flowers' => ['nullable', 'string', 'max:255'],
            'preferred_colors' => ['nullable', 'string', 'max:255'],
            'bouquet_size' => ['nullable', 'string', 'max:60'],
            'budget' => ['required', 'numeric', 'min:0'],
            'requested_delivery_date' => ['required', 'date', 'after_or_equal:today'],
            'requested_delivery_time' => ['nullable', 'string', 'max:20'],
            'personalized_message' => ['nullable', 'string', 'max:1000'],
            'reference_image_url' => ['nullable', 'string', 'max:500'],
        ]);

        $customRequest = CustomRequest::create([
            ...$data,
            'request_number' => 'CR-'.now()->format('ymd').'-'.Str::upper(Str::random(4)),
            'customer_id' => $request->user()->id,
            'status' => 'new',
        ]);

        $this->notifier->customRequestSubmitted($customRequest);

        return response()->json([
            'message' => 'Request sent. The shop will review it shortly.',
            'data' => $this->payload($customRequest),
        ], 201);
    }

    private function payload(CustomRequest $r): array
    {
        return [
            'id' => $r->id,
            'request_number' => $r->request_number,
            'occasion' => $r->occasion,
            'preferred_flowers' => $r->preferred_flowers,
            'preferred_colors' => $r->preferred_colors,
            'bouquet_size' => $r->bouquet_size,
            'budget' => (float) $r->budget,
            'requested_delivery_date' => $r->requested_delivery_date?->format('Y-m-d'),
            'requested_delivery_time' => $r->requested_delivery_time,
            'personalized_message' => $r->personalized_message,
            'status' => $r->status,
            'estimated_price' => $r->estimated_price !== null ? (float) $r->estimated_price : null,
            'admin_notes' => $r->admin_notes,
            'created_at' => $r->created_at?->toIso8601String(),
        ];
    }
}
