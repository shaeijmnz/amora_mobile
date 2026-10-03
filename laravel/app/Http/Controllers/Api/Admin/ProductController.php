<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

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
        if (! $request->hasFile('image')) {
            return response()->json([
                'message' => 'Choose a JPG, PNG, or WebP photo (8 MB max).',
            ], 422);
        }

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:8192'],
        ]);

        $file = $request->file('image');
        $extension = $file->extension() ?: 'jpg';
        $filename = Str::uuid()->toString().'.'.$extension;
        $path = $file->storeAs('products', $filename, 'public');
        $stored = Storage::disk('public')->path($path);

        $publicDir = $this->publicUploadDirectory();
        if ($publicDir) {
            if (! copy($stored, $publicDir.'/'.$filename)) {
                return response()->json(['message' => 'Could not publish the photo.'], 500);
            }
            chmod($publicDir.'/'.$filename, 0644);

            return response()->json(['url' => '/images/uploads/'.$filename]);
        }

        return response()->json(['url' => '/storage/'.$path]);
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

        $images = array_values($data['images'] ?? []);
        $primaryUrl = $data['primary_image_url'] ?? ($images[0] ?? null);

        $product = Product::create([
            'name'                     => $data['name'],
            'category'                 => $data['category'] ?? 'flower',
            'description'              => $data['description'] ?? null,
            'primary_image_url'        => $primaryUrl,
            'gallery_image_urls'       => $images,
            'is_available'             => $data['is_available'] ?? true,
            'is_featured'              => $data['is_featured'] ?? false,
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
        unset($data['sizes'], $data['is_customisable'], $data['customisation_items']);

        if (array_key_exists('images', $data)) {
            $images = array_values($data['images'] ?? []);
            $data['gallery_image_urls'] = $images;
            unset($data['images']);
            if (empty($data['primary_image_url']) && $images !== []) {
                $data['primary_image_url'] = $images[0];
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

    private function publicUploadDirectory(): ?string
    {
        $dir = '/var/www/amora-mobile/images/uploads';

        return is_dir($dir) && is_writable($dir) ? $dir : null;
    }

    private function payload(Product $p): array
    {
        $gallery = is_array($p->gallery_image_urls) ? array_values($p->gallery_image_urls) : [];
        $images = $gallery !== [] ? $gallery : ($p->primary_image_url ? [$p->primary_image_url] : []);

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
