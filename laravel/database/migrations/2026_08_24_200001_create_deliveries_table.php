<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->string('status')->default('unscheduled');
            $table->string('assigned_rider')->nullable();
            $table->date('scheduled_date')->nullable();
            $table->string('scheduled_time')->nullable();
            $table->text('delivery_instructions')->nullable();
            $table->string('failed_reason')->nullable();
            $table->string('proof_of_delivery_url')->nullable();
            $table->json('attempts')->nullable();
            $table->timestamps();

            $table->unique('order_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('deliveries');
    }
};
