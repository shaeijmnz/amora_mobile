<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'request_number',
    'customer_id',
    'occasion',
    'preferred_flowers',
    'preferred_colors',
    'bouquet_size',
    'budget',
    'requested_delivery_date',
    'requested_delivery_time',
    'personalized_message',
    'reference_image_url',
    'status',
    'estimated_price',
    'admin_notes',
    'order_id',
])]
class CustomRequest extends Model
{
    protected function casts(): array
    {
        return [
            'requested_delivery_date' => 'date',
            'budget' => 'decimal:2',
            'estimated_price' => 'decimal:2',
        ];
    }

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
