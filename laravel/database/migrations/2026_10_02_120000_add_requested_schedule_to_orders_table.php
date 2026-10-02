<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->date('requested_delivery_date')->nullable()->after('delivery_notes');
            $table->string('requested_delivery_time')->nullable()->after('requested_delivery_date');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['requested_delivery_date', 'requested_delivery_time']);
        });
    }
};
