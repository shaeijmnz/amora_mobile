<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = Product::query()
            ->with('sizes')
            ->withCount('orderItems as orders')
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

    public function uploadImage(Request $request)
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:5120'],
        ]);

        $path = $request->file('image')->store('products', 'public');

        return response()->json([
            'url' => config('app.url') . '/storage/' . $path,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name'                     => ['required', 'string', 'max:160'],
            'category'                 => ['nullable', 'string', 'max:60'],
            'description'              => ['nullable', 'string'],
            'primary_image_url'        => ['nullable', 'string', 'max:500'],
            'images'                   => ['nullable', 'array'],
            'images.*'                 => ['string'],
            'is_available'             => ['boolean'],
            'is_featured'              => ['boolean'],
            'is_customisable'          => ['boolean'],
            'customisation_items'      => ['nullable', 'array'],
            'preparation_time_minutes' => ['nullable', 'integer', 'min:0'],
            'sizes'                    => ['required', 'array', 'min:1'],
            'sizes.*.label'            => ['required', 'string'],
            'sizes.*.price'            => ['required', 'numeric', 'min:0'],
        ]);

        $images = $data['images'] ?? [];
        $primaryUrl = $data['primary_image_url'] ?? ($images[0] ?? null);

        $product = Product::create([
            'name'                     => $data['name'],
            'category'                 => $data['category'] ?? 'flower',
            'description'              => $data['description'] ?? null,
            'primary_image_url'        => $primaryUrl,
            'images'                   => $images,
            'is_available'             => $data['is_available'] ?? true,
            'is_featured'              => $data['is_featured'] ?? false,
            'is_customisable'          => $data['is_customisable'] ?? false,
            'customisation_items'      => $data['customisation_items'] ?? null,
            'preparation_time_minutes' => $data['preparation_time_minutes'] ?? 45,
            'rating'                   => 4.5,
            'reviews_count'            => 0,
        ]);

        foreach ($data['sizes'] as $size) {
            $product->sizes()->create($size);
        }

        $product->load('sizes')->loadCount('orderItems as orders');

        return response()->json(['data' => $this->payload($product)], 201);
    }

    public function update(Request $request, Product $product)
    {
        $data = $request->validate([
            'name'                     => ['sometimes', 'string', 'max:160'],
            'category'                 => ['sometimes', 'nullable', 'string', 'max:60'],
            'description'              => ['sometimes', 'nullable', 'string'],
            'primary_image_url'        => ['sometimes', 'nullable', 'string', 'max:500'],
            'images'                   => ['sometimes', 'nullable', 'array'],
            'images.*'                 => ['string'],
            'is_available'             => ['sometimes', 'boolean'],
            'is_featured'              => ['sometimes', 'boolean'],
            'is_customisable'          => ['sometimes', 'boolean'],
            'customisation_items'      => ['sometimes', 'nullable', 'array'],
            'preparation_time_minutes' => ['sometimes', 'integer', 'min:0'],
            'sizes'                    => ['sometimes', 'array', 'min:1'],
            'sizes.*.label'            => ['required_with:sizes', 'string'],
            'sizes.*.price'            => ['required_with:sizes', 'numeric', 'min:0'],
        ]);

        $sizes = $data['sizes'] ?? null;
        unset($data['sizes']);

        if (isset($data['images']) && is_array($data['images']) && !empty($data['images'])) {
            if (empty($data['primary_image_url'])) {
                $data['primary_image_url'] = $data['images'][0];
            }
        }

        $product->update($data);

        if ($sizes !== null) {
            $product->sizes()->delete();
            foreach ($sizes as $size) {
                $product->sizes()->create($size);
            }
        }

        $product->load('sizes')->loadCount('orderItems as orders');

        return response()->json(['data' => $this->payload($product)]);
    }

    public function duplicate(Product $product)
    {
        $newProduct = $product->replicate();
        $newProduct->name = $product->name . ' (Copy)';
        $newProduct->is_featured = false;
        $newProduct->save();

        foreach ($product->sizes as $size) {
            $newProduct->sizes()->create([
                'label' => $size->label,
                'price' => $size->price,
            ]);
        }

        $newProduct->load('sizes')->loadCount('orderItems as orders');

        return response()->json(['data' => $this->payload($newProduct)], 201);
    }

    private function payload(Product $p): array
    {
        $images = $p->images ?? ($p->primary_image_url ? [$p->primary_image_url] : []);

        return [
            'id'                       => $p->id,
            'name'                     => $p->name,
            'category'                 => $p->category,
            'description'              => $p->description,
            'primary_image_url'        => $p->primary_image_url ?? ($images[0] ?? null),
            'images'                   => $images,
            'is_available'             => (bool) $p->is_available,
            'is_featured'              => (bool) $p->is_featured,
            'is_customisable'          => (bool) $p->is_customisable,
            'customisation_items'      => $p->customisation_items ?? [],
            'rating'                   => (float) ($p->rating ?? 4.5),
            'reviews_count'            => (int) ($p->reviews_count ?? 0),
            'preparation_time_minutes' => (int) ($p->preparation_time_minutes ?? 45),
            'occasions'                => array_values(array_filter([$p->category])),
            'orders'                   => (int) ($p->orders ?? 0),
            'sizes'                    => $p->sizes->map(fn ($s) => [
                'id'    => $s->id,
                'label' => $s->label,
                'price' => (float) $s->price,
            ])->values(),
        ];
    }
}
