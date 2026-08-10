<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
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
}
