<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'name',
    'category',
    'description',
    'primary_image_url',
    'preparation_time_minutes',
    'is_available',
    'is_featured',
    'rating',
    'reviews_count',
    'archived_at',
])]
class Product extends Model
{
    protected function casts(): array
    {
        return [
            'is_available' => 'boolean',
            'is_featured' => 'boolean',
            'rating' => 'float',
            'archived_at' => 'datetime',
        ];
    }

    public function sizes()
    {
        return $this->hasMany(ProductSize::class);
    }

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }
}
