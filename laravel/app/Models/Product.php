<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'name',
    'category',
    'description',
    'primary_image_url',
    'images',
    'is_customisable',
    'customisation_items',
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
            'is_customisable' => 'boolean',
            'rating' => 'float',
            'images' => 'array',
            'customisation_items' => 'array',
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
