<?php

namespace App\Services;

use App\Mail\OtpVerificationMail;
use App\Models\User;
use Illuminate\Support\Facades\Mail;

class OtpService
{
    public function issue(User $user): string
    {
        $otp = (string) random_int(100000, 999999);

        $user->forceFill([
            'otp_code' => $otp,
            'otp_expires_at' => now()->addMinutes(10),
            'email_verified_at' => null,
        ])->save();

        Mail::to($user->email)->send(new OtpVerificationMail($user->name, $otp));

        return $otp;
    }

    public function verify(User $user, string $otp): bool
    {
        if (! $user->otp_code || ! $user->otp_expires_at) {
            return false;
        }

        if (now()->greaterThan($user->otp_expires_at)) {
            return false;
        }

        if (! hash_equals((string) $user->otp_code, $otp)) {
            return false;
        }

        $user->forceFill([
            'email_verified_at' => now(),
            'otp_code' => null,
            'otp_expires_at' => null,
        ])->save();

        return true;
    }
}
