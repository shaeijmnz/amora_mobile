<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = Product::query()
            ->whereNull('archived_at')
            ->where('is_available', true)
            ->with('sizes')
            ->when($request->boolean('featured'), fn ($q) => $q->where('is_featured', true))
            ->orderByDesc('is_featured')
            ->orderBy('name')
            ->get()
            ->map(fn (Product $product) => $this->productPayload($product));

        return response()->json(['data' => $products]);
    }

    public function show(Product $product)
    {
        if ($product->archived_at || ! $product->is_available) {
            return response()->json(['message' => 'Product not found.'], 404);
        }

        $product->load('sizes');

        return response()->json(['data' => $this->productPayload($product)]);
    }

    private function productPayload(Product $product): array
    {
        $price = (float) ($product->sizes->min('price') ?? 0);

        return [
            'id' => $product->id,
            'name' => $product->name,
            'category' => $product->category ?? 'flower',
            'description' => $product->description,
            'primary_image_url' => $product->primary_image_url,
            'preparation_time_minutes' => $product->preparation_time_minutes,
            'is_featured' => (bool) $product->is_featured,
            'rating' => (float) ($product->rating ?? 4.5),
            'reviews_count' => (int) ($product->reviews_count ?? 0),
            'price' => $price,
            'price_label' => 'Php. '.number_format($price, 2),
            'sizes' => $product->sizes->map(fn ($size) => [
                'id' => $size->id,
                'label' => $size->label,
                'price' => (float) $size->price,
            ])->values(),
        ];
    }
}
