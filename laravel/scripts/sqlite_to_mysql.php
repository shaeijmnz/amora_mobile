<?php

/**
 * One-off port of the demo data from the old SQLite file into MySQL.
 * Run with: php artisan tinker --execute="require 'scripts/sqlite_to_mysql.php';"
 */

use Illuminate\Support\Facades\DB;

$sqlitePath = __DIR__.'/../database/database.sqlite';

config(['database.connections.legacy_sqlite' => [
    'driver' => 'sqlite',
    'database' => $sqlitePath,
    'prefix' => '',
    'foreign_key_constraints' => false,
]]);

$legacy = DB::connection('legacy_sqlite');
$target = DB::connection();

// Parents before children so foreign keys resolve.
$tables = [
    'users',
    'categories',
    'products',
    'product_sizes',
    'inventory_items',
    'orders',
    'order_items',
    'deliveries',
    'admin_notifications',
    'inventory_movements',
    'personal_access_tokens',
];

$target->statement('SET FOREIGN_KEY_CHECKS=0');

foreach ($tables as $table) {
    if (! $legacy->getSchemaBuilder()->hasTable($table)) {
        echo str_pad($table, 26)." skipped (not in sqlite)\n";
        continue;
    }

    $targetColumns = $target->getSchemaBuilder()->getColumnListing($table);
    $rows = $legacy->table($table)->get();

    $target->table($table)->truncate();

    $inserted = 0;
    foreach ($rows->chunk(100) as $chunk) {
        $payload = $chunk->map(function ($row) use ($targetColumns) {
            // Drop columns the old file had but MySQL does not.
            return array_intersect_key((array) $row, array_flip($targetColumns));
        })->all();

        if ($payload !== []) {
            $target->table($table)->insert($payload);
            $inserted += count($payload);
        }
    }

    echo str_pad($table, 26)." {$inserted} rows\n";
}

$target->statement('SET FOREIGN_KEY_CHECKS=1');

echo "\nDone.\n";
