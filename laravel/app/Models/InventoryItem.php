<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'product_id',
    'name',
    'category_id',
    'image_url',
    'unit',
    'quantity_on_hand',
    'min_stock_level',
    'status',
    'expiration_date',
    'archived_at',
])]
class InventoryItem extends Model
{
    protected function casts(): array
    {
        return [
            'expiration_date' => 'date',
            'archived_at' => 'datetime',
        ];
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function syncStockStatus(): void
    {
        if ($this->quantity_on_hand <= 0) {
            $this->status = 'out_of_stock';
        } elseif ($this->quantity_on_hand < $this->min_stock_level) {
            $this->status = 'low_stock';
        } else {
            $this->status = 'in_stock';
        }
    }
}
