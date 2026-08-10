<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = Product::query()
            ->with('sizes')
            ->withCount('orderItems as orders')
            ->when($request->boolean('include_archived') === false, fn ($q) => $q->whereNull('archived_at'))
            ->when(! $request->has('include_archived'), fn ($q) => $q->whereNull('archived_at'))
            ->orderByDesc('is_featured')
            ->orderBy('name')
            ->get()
            ->map(fn (Product $p) => $this->payload($p));

        return response()->json(['data' => $products]);
    }

    public function show(Product $product)
    {
        $product->load('sizes')->loadCount('orderItems as orders');

        return response()->json(['data' => $this->payload($product)]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:60'],
            'description' => ['nullable', 'string'],
            'primary_image_url' => ['nullable', 'string', 'max:500'],
            'is_available' => ['boolean'],
            'is_featured' => ['boolean'],
            'sizes' => ['required', 'array', 'min:1'],
            'sizes.*.label' => ['required', 'string'],
            'sizes.*.price' => ['required', 'numeric', 'min:0'],
        ]);

        $product = Product::create([
            'name' => $data['name'],
            'category' => $data['category'] ?? 'flower',
            'description' => $data['description'] ?? null,
            'primary_image_url' => $data['primary_image_url'] ?? null,
            'is_available' => $data['is_available'] ?? true,
            'is_featured' => $data['is_featured'] ?? false,
            'preparation_time_minutes' => 45,
            'rating' => 4.5,
            'reviews_count' => 0,
        ]);

        foreach ($data['sizes'] as $size) {
            $product->sizes()->create($size);
        }

        $product->load('sizes')->loadCount('orderItems as orders');

        return response()->json(['data' => $this->payload($product)], 201);
    }

    private function payload(Product $p): array
    {
        return [
            'id' => $p->id,
            'name' => $p->name,
            'category' => $p->category,
            'description' => $p->description,
            'primary_image_url' => $p->primary_image_url,
            'is_available' => (bool) $p->is_available,
            'is_featured' => (bool) $p->is_featured,
            'rating' => (float) ($p->rating ?? 4.5),
            'reviews_count' => (int) ($p->reviews_count ?? 0),
            'occasions' => array_values(array_filter([$p->category])),
            'orders' => (int) ($p->orders ?? 0),
            'sizes' => $p->sizes->map(fn ($s) => [
                'id' => $s->id,
                'label' => $s->label,
                'price' => (float) $s->price,
            ])->values(),
        ];
    }
}
