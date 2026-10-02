<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'inventory_item_id',
    'item_name',
    'type',
    'quantity',
    'previous_qty',
    'new_qty',
    'reason',
    'order_id',
    'order_number',
    'performed_by',
])]
class InventoryMovement extends Model
{
    public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class);
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
