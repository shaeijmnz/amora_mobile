<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'group'])]
class Category extends Model
{
    public function inventoryItems()
    {
        return $this->hasMany(InventoryItem::class);
    }
}
