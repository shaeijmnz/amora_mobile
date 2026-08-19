<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\InventoryItem;
use App\Models\Product;
use Illuminate\Database\Seeder;

class InventorySeeder extends Seeder
{
    public function run(): void
    {
        InventoryItem::query()->delete();

        $shop = Category::updateOrCreate(
            ['name' => 'Shop Products'],
            ['group' => 'flower']
        );

        foreach (Product::query()->orderBy('name')->get() as $product) {
            InventoryItem::updateOrCreate(
                ['product_id' => $product->id],
                [
                    'name' => $product->name,
                    'category_id' => $shop->id,
                    'image_url' => $product->primary_image_url,
                    'unit' => 'pcs',
                    'quantity_on_hand' => 20,
                    'min_stock_level' => 5,
                    'status' => 'in_stock',
                ]
            );
        }
    }
}
