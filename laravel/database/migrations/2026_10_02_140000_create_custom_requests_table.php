<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('custom_requests', function (Blueprint $table) {
            $table->id();
            $table->string('request_number')->unique();
            $table->foreignId('customer_id')->constrained('users')->cascadeOnDelete();
            $table->string('occasion');
            $table->string('preferred_flowers')->nullable();
            $table->string('preferred_colors')->nullable();
            $table->string('bouquet_size')->nullable();
            $table->decimal('budget', 10, 2)->default(0);
            $table->date('requested_delivery_date')->nullable();
            $table->string('requested_delivery_time')->nullable();
            $table->text('personalized_message')->nullable();
            $table->string('reference_image_url')->nullable();
            // new | under_review | awaiting_customer_approval | approved
            // | in_preparation | completed | rejected | cancelled
            $table->string('status')->default('new');
            $table->decimal('estimated_price', 10, 2)->nullable();
            $table->text('admin_notes')->nullable();
            $table->foreignId('order_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('custom_requests');
    }
};
