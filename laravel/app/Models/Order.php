<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'order_number',
    'customer_id',
    'order_type',
    'status',
    'payment_status',
    'payment_method',
    'paymongo_checkout_id',
    'paymongo_payment_id',
    'paid_at',
    'subtotal',
    'delivery_fee',
    'discount',
    'total',
    'recipient_name',
    'recipient_contact',
    'delivery_address',
    'delivery_notes',
    'admin_notes',
])]
class Order extends Model
{
    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'delivery_fee' => 'decimal:2',
            'discount' => 'decimal:2',
            'total' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function delivery()
    {
        return $this->hasOne(Delivery::class);
    }
}
