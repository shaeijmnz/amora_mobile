<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\InventoryItem;
use Illuminate\Database\Seeder;

class InventorySeeder extends Seeder
{
    public function run(): void
    {
        $flower = Category::updateOrCreate(
            ['name' => 'Roses'],
            ['group' => 'flower']
        );

        $material = Category::updateOrCreate(
            ['name' => 'Wrapping'],
            ['group' => 'material']
        );

        $addon = Category::updateOrCreate(
            ['name' => 'Add-ons'],
            ['group' => 'addon']
        );

        $items = [
            [
                'name' => 'Dusty Pink Rose',
                'category_id' => $flower->id,
                'unit' => 'stems',
                'quantity_on_hand' => 120,
                'min_stock_level' => 20,
                'status' => 'in_stock',
            ],
            [
                'name' => 'Red Rose',
                'category_id' => $flower->id,
                'unit' => 'stems',
                'quantity_on_hand' => 80,
                'min_stock_level' => 25,
                'status' => 'in_stock',
            ],
            [
                'name' => 'Baby Breath',
                'category_id' => $flower->id,
                'unit' => 'bunches',
                'quantity_on_hand' => 8,
                'min_stock_level' => 10,
                'status' => 'low_stock',
            ],
            [
                'name' => 'Kraft Wrap',
                'category_id' => $material->id,
                'unit' => 'sheets',
                'quantity_on_hand' => 200,
                'min_stock_level' => 40,
                'status' => 'in_stock',
            ],
            [
                'name' => 'Chocolate Box',
                'category_id' => $addon->id,
                'unit' => 'pcs',
                'quantity_on_hand' => 35,
                'min_stock_level' => 10,
                'status' => 'in_stock',
            ],
        ];

        foreach ($items as $item) {
            InventoryItem::updateOrCreate(
                ['name' => $item['name']],
                $item
            );
        }
    }
}
