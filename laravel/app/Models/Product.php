<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'name',
    'category',
    'description',
    'note',
    'primary_image_url',
    'gallery_image_urls',
    'images',
    'is_customisable',
    'customisation_items',
    'preparation_time_minutes',
    'is_available',
    'is_featured',
    'is_stem',
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
            'gallery_image_urls' => 'array',
            'is_stem' => 'boolean',
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
