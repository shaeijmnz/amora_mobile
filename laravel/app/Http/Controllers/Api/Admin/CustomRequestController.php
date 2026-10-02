<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\CustomRequest;
use Illuminate\Http\Request;

class CustomRequestController extends Controller
{
    public function index(Request $request)
    {
        $requests = CustomRequest::query()
            ->with('customer')
            ->when(
                $request->status && $request->status !== 'all',
                fn ($q) => $q->where('status', $request->status)
            )
            ->latest()
            ->get()
            ->map(fn (CustomRequest $r) => $this->payload($r));

        return response()->json(['data' => $requests]);
    }

    public function show(CustomRequest $customRequest)
    {
        $customRequest->load('customer');

        return response()->json(['data' => $this->payload($customRequest)]);
    }

    public function update(Request $request, CustomRequest $customRequest)
    {
        $data = $request->validate([
            'status' => ['sometimes', 'string', 'in:new,under_review,awaiting_customer_approval,approved,in_preparation,completed,rejected,cancelled'],
            'estimated_price' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'admin_notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ]);

        // Approving without a price leaves the customer nothing to agree to.
        $status = $data['status'] ?? $customRequest->status;
        $price = array_key_exists('estimated_price', $data)
            ? $data['estimated_price']
            : $customRequest->estimated_price;

        if ($status === 'approved' && blank($price)) {
            return response()->json(['message' => 'Set an estimated price before approving.'], 422);
        }

        $customRequest->update($data);
        $customRequest->load('customer');

        return response()->json([
            'message' => 'Request updated.',
            'data' => $this->payload($customRequest),
        ]);
    }

    private function payload(CustomRequest $r): array
    {
        return [
            'id' => $r->id,
            'request_number' => $r->request_number,
            'customer' => $r->customer?->name,
            'customer_email' => $r->customer?->email,
            'customer_contact' => $r->customer?->phone,
            'occasion' => $r->occasion,
            'preferred_flowers' => $r->preferred_flowers,
            'preferred_colors' => $r->preferred_colors,
            'bouquet_size' => $r->bouquet_size,
            'budget' => (float) $r->budget,
            'requested_delivery_date' => $r->requested_delivery_date?->format('Y-m-d'),
            'requested_delivery_time' => $r->requested_delivery_time,
            'personalized_message' => $r->personalized_message,
            'reference_image_url' => $r->reference_image_url,
            'status' => $r->status,
            'estimated_price' => $r->estimated_price !== null ? (float) $r->estimated_price : null,
            'admin_notes' => $r->admin_notes,
            'created_at' => $r->created_at?->toIso8601String(),
        ];
    }
}
