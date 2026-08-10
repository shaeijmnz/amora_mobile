<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AmoraSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'customer@amoraflorals.com'],
            [
                'name' => 'Amora Customer',
                'password' => Hash::make('customer123'),
                'role' => 'customer',
                'phone' => '09171234567',
                'email_verified_at' => now(),
                'otp_code' => null,
                'otp_expires_at' => null,
            ]
        );

        User::updateOrCreate(
            ['email' => 'admin@amoraflorals.com'],
            [
                'name' => 'Amora Admin',
                'password' => Hash::make('password123'),
                'role' => 'admin',
                'phone' => '09179876543',
                'email_verified_at' => now(),
                'otp_code' => null,
                'otp_expires_at' => null,
            ]
        );
    }
}
