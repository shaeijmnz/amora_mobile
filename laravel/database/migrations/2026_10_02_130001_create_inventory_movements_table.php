<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_movements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inventory_item_id')->nullable()->constrained()->nullOnDelete();
            // Kept denormalised so history survives an archived/deleted item.
            $table->string('item_name');
            // stock_in | stock_out | adjustment | damaged | spoiled | reserved_release
            $table->string('type');
            $table->integer('quantity');
            $table->integer('previous_qty')->default(0);
            $table->integer('new_qty')->default(0);
            $table->string('reason')->nullable();
            $table->foreignId('order_id')->nullable()->constrained()->nullOnDelete();
            $table->string('order_number')->nullable();
            $table->string('performed_by')->nullable();
            $table->timestamps();

            $table->index(['type', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_movements');
    }
};
