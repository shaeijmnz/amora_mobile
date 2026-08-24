<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'order_id',
    'status',
    'assigned_rider',
    'scheduled_date',
    'scheduled_time',
    'delivery_instructions',
    'failed_reason',
    'proof_of_delivery_url',
    'attempts',
])]
class Delivery extends Model
{
    protected function casts(): array
    {
        return [
            'scheduled_date' => 'date',
            'attempts' => 'array',
        ];
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
