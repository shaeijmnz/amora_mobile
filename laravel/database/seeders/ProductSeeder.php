<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('order_items')->delete();
        DB::table('product_sizes')->delete();
        DB::table('products')->delete();

        $description = 'Pre-order bloom from Amora Florals. Prices may change without prior notice due to supply and seasonal fluctuations. Free greeting card included.';
        $stemNote = 'Price per stem, unarranged. Additional charges may apply if arranged as a bouquet.';

        $catalog = [
            [
                'name' => 'China Roses Bouquet',
                'category' => 'bouquet rose',
                'image' => '/images/products/china_roses.jpg',
                'gallery' => ['/images/products/china_roses_1.jpg'],
                'rating' => 4.9,
                'reviews' => 86,
                'featured' => true,
                'is_stem' => false,
                'sizes' => [
                    ['label' => '1pc', 'price' => 1],
                    ['label' => '3pcs', 'price' => 1],
                    ['label' => '5pcs', 'price' => 1],
                    ['label' => '10pcs', 'price' => 1],
                ],
            ],
            [
                'name' => 'Sunflower Bouquet',
                'category' => 'bouquet sunflower',
                'image' => '/images/products/sunflower.jpg',
                'gallery' => ['/images/products/sunflower_1.jpg'],
                'rating' => 4.8,
                'reviews' => 74,
                'featured' => true,
                'is_stem' => false,
                'sizes' => [
                    ['label' => '1pc', 'price' => 1],
                    ['label' => '3pcs', 'price' => 1],
                    ['label' => '5pcs', 'price' => 1],
                    ['label' => '10pcs', 'price' => 1],
                ],
            ],
            [
                'name' => 'Gerbera / Daisy Bouquet',
                'category' => 'bouquet daisy gerbera',
                'image' => '/images/products/gerbera_daisy.jpg',
                'gallery' => ['/images/products/gerbera_daisy_1.jpg'],
                'rating' => 4.8,
                'reviews' => 91,
                'featured' => true,
                'is_stem' => false,
                'sizes' => [
                    ['label' => '1pc', 'price' => 1],
                    ['label' => '3pcs', 'price' => 1],
                    ['label' => '5pcs', 'price' => 1],
                    ['label' => '10pcs', 'price' => 1],
                ],
            ],
            [
                'name' => 'Carnation Bouquet',
                'category' => 'bouquet carnation',
                'image' => '/images/products/carnation.jpg',
                'gallery' => ['/images/products/carnation_1.jpg'],
                'rating' => 4.7,
                'reviews' => 68,
                'featured' => true,
                'is_stem' => false,
                'sizes' => [
                    ['label' => '1pc', 'price' => 1],
                    ['label' => '3pcs', 'price' => 1],
                    ['label' => '5pcs', 'price' => 1],
                    ['label' => '10pcs', 'price' => 1],
                ],
            ],
            [
                'name' => 'Stargazer Lilies',
                'category' => 'stem lily',
                'image' => '/images/products/stargazer_lilies.jpg',
                'gallery' => ['/images/products/stargazer_lilies_1.jpg'],
                'rating' => 4.9,
                'reviews' => 52,
                'featured' => false,
                'is_stem' => true,
                'note' => $stemNote,
                'sizes' => [
                    ['label' => '1 stem', 'price' => 1],
                ],
            ],
            [
                'name' => 'Sunlight Chrysanthemum',
                'category' => 'stem chrysanthemum',
                'image' => '/images/products/sunlight_chrysanthemum.jpg',
                'gallery' => ['/images/products/sunlight_chrysanthemum_1.jpg'],
                'rating' => 4.7,
                'reviews' => 41,
                'featured' => false,
                'is_stem' => true,
                'note' => $stemNote,
                'sizes' => [
                    ['label' => '1 stem', 'price' => 1],
                ],
            ],
            [
                'name' => 'Hydrangea',
                'category' => 'stem hydrangea',
                'image' => '/images/products/hydrangea.jpg',
                'gallery' => ['/images/products/hydrangea_1.jpg'],
                'rating' => 4.8,
                'reviews' => 57,
                'featured' => false,
                'is_stem' => true,
                'note' => $stemNote,
                'sizes' => [
                    ['label' => '1 stem', 'price' => 1],
                ],
            ],
        ];

        foreach ($catalog as $item) {
            $product = Product::create([
                'name' => $item['name'],
                'category' => $item['category'],
                'description' => $description,
                'note' => $item['note'] ?? null,
                'primary_image_url' => $item['image'],
                'gallery_image_urls' => $item['gallery'],
                'preparation_time_minutes' => 45,
                'is_available' => true,
                'is_featured' => $item['featured'],
                'is_stem' => $item['is_stem'],
                'rating' => $item['rating'],
                'reviews_count' => $item['reviews'],
            ]);

            foreach ($item['sizes'] as $size) {
                $product->sizes()->create($size);
            }
        }
    }
};
