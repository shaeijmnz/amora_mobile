<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        // Replace old demo bouquets with the customer-app catalog.
        DB::table('order_items')->delete();
        DB::table('product_sizes')->delete();
        DB::table('products')->delete();

        $catalog = [
            ['name' => 'Daisy', 'category' => 'flower', 'price' => 125, 'rating' => 4.5, 'reviews' => 128, 'featured' => true, 'image' => 'https://plus.unsplash.com/premium_photo-1667867937010-77fd5161cf8d?fm=jpg&q=60&w=3000&auto=format&fit=crop'],
            ['name' => 'Sunflower', 'category' => 'sunflower', 'price' => 135, 'rating' => 4.5, 'reviews' => 96, 'featured' => true, 'image' => 'https://images.unsplash.com/photo-1597848212624-a19eb35e2651?w=800'],
            ['name' => 'Tulips', 'category' => 'tulip', 'price' => 125, 'rating' => 4.5, 'reviews' => 232, 'featured' => true, 'image' => 'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=800'],
            ['name' => 'Red Rose', 'category' => 'rose', 'price' => 135, 'rating' => 4.5, 'reviews' => 310, 'featured' => true, 'image' => 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=800'],
            ['name' => 'Stargazer Lilies', 'category' => 'lily', 'price' => 125, 'rating' => 4.5, 'reviews' => 84, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?w=800'],
            ['name' => 'Lavender', 'category' => 'lavender', 'price' => 135, 'rating' => 4.5, 'reviews' => 157, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1499002238440-d36275179963?w=800'],
            ['name' => 'Peony', 'category' => 'peony', 'price' => 185, 'rating' => 4.8, 'reviews' => 204, 'featured' => true, 'image' => 'https://images.unsplash.com/photo-1508610048659-a06b669e3321?w=800'],
            ['name' => 'Cherry Blossom', 'category' => 'blossom', 'price' => 165, 'rating' => 4.7, 'reviews' => 178, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800'],
            ['name' => 'Orchid', 'category' => 'orchid', 'price' => 195, 'rating' => 4.6, 'reviews' => 142, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1561181286-d3fee7f52978?w=800'],
            ['name' => 'Carnation', 'category' => 'carnation', 'price' => 115, 'rating' => 4.4, 'reviews' => 119, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1468327768560-75b630cdd0d3?w=800'],
            ['name' => 'Hydrangea', 'category' => 'hydrangea', 'price' => 175, 'rating' => 4.7, 'reviews' => 166, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1508610048659-a06b669e3321?w=800'],
            ['name' => "Baby's Breath", 'category' => 'filler', 'price' => 95, 'rating' => 4.5, 'reviews' => 211, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1487530811176-3780de880c2d?w=800'],
            ['name' => 'Ranunculus', 'category' => 'ranunculus', 'price' => 155, 'rating' => 4.8, 'reviews' => 133, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1455659817273-f96807779a8a?w=800'],
            ['name' => 'Anemone', 'category' => 'anemone', 'price' => 145, 'rating' => 4.6, 'reviews' => 98, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1465146633011-14f8e0781093?w=800'],
            ['name' => 'Gardenia', 'category' => 'gardenia', 'price' => 160, 'rating' => 4.7, 'reviews' => 121, 'featured' => false, 'image' => 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800'],
        ];

        foreach ($catalog as $item) {
            $product = Product::create([
                'name' => $item['name'],
                'category' => $item['category'],
                'description' => $item['name'].' — available in the Amora Florals customer shop.',
                'primary_image_url' => $item['image'],
                'preparation_time_minutes' => 45,
                'is_available' => true,
                'is_featured' => $item['featured'],
                'rating' => $item['rating'],
                'reviews_count' => $item['reviews'],
            ]);

            $product->sizes()->create([
                'label' => 'Standard',
                'price' => $item['price'],
            ]);
        }
    }
}
