<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->json('gallery_image_urls')->nullable()->after('primary_image_url');
            $table->boolean('is_stem')->default(false)->after('is_featured');
            $table->text('note')->nullable()->after('description');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['gallery_image_urls', 'is_stem', 'note']);
        });
    }
};
