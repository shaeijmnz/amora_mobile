<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_items', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->string('image_url')->nullable();
            $table->string('unit')->default('pcs');
            $table->integer('quantity_on_hand')->default(0);
            $table->integer('min_stock_level')->default(5);
            // in_stock | low_stock | out_of_stock | reserved | damaged | spoiled
            $table->string('status')->default('in_stock');
            $table->date('expiration_date')->nullable();
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_items');
    }
};
