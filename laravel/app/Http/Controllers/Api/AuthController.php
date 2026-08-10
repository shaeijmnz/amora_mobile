<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private OtpService $otp) {}

    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:120'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:6'],
            'phone' => ['nullable', 'string', 'max:40'],
        ]);

        $email = strtolower($data['email']);
        $existing = User::where('email', $email)->first();

        // Any email is allowed. If already verified → ask them to log in.
        if ($existing && $existing->email_verified_at) {
            throw ValidationException::withMessages([
                'email' => ['This email is already registered. Please log in.'],
            ]);
        }

        // Unverified account (or new) → create/update then send OTP to THAT email.
        if ($existing) {
            $existing->forceFill([
                'name' => $data['name'],
                'password' => $data['password'],
                'phone' => $data['phone'] ?? $existing->phone,
                'role' => 'customer',
            ])->save();
            $user = $existing;
        } else {
            $user = User::create([
                'name' => $data['name'],
                'email' => $email,
                'password' => $data['password'],
                'phone' => $data['phone'] ?? null,
                'role' => 'customer',
                'email_verified_at' => null,
            ]);
        }

        $code = $this->otp->issue($user);

        $payload = [
            'message' => 'We sent a 6-digit verification code to your email.',
            'email' => $user->email,
            'needs_verification' => true,
        ];

        if (config('app.debug')) {
            $payload['debug_otp'] = $code;
        }

        return response()->json($payload, $existing ? 200 : 201);
    }

    public function verifyOtp(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'otp' => ['required', 'string', 'size:6'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if (! $user || $user->role !== 'customer') {
            throw ValidationException::withMessages([
                'email' => ['Account not found.'],
            ]);
        }

        if ($user->email_verified_at) {
            $token = $user->createToken('mobile')->plainTextToken;

            return response()->json([
                'message' => 'Already verified.',
                'token' => $token,
                'user' => $this->userPayload($user),
            ]);
        }

        if (! $this->otp->verify($user, $data['otp'])) {
            throw ValidationException::withMessages([
                'otp' => ['Invalid or expired code. Try again or resend.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Email verified. Welcome!',
            'token' => $token,
            'user' => $this->userPayload($user->fresh()),
        ]);
    }

    public function resendOtp(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if (! $user || $user->role !== 'customer') {
            throw ValidationException::withMessages([
                'email' => ['Account not found.'],
            ]);
        }

        if ($user->email_verified_at) {
            return response()->json(['message' => 'Account already verified. You can log in.']);
        }

        $code = $this->otp->issue($user);

        $payload = [
            'message' => 'A new verification code was sent to your email.',
            'email' => $user->email,
        ];

        if (config('app.debug')) {
            $payload['debug_otp'] = $code;
        }

        return response()->json($payload);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Wrong email or password.'],
            ]);
        }

        if ($user->role !== 'customer') {
            throw ValidationException::withMessages([
                'email' => ['This account is not a customer account.'],
            ]);
        }

        if (! $user->email_verified_at) {
            $code = $this->otp->issue($user);

            $payload = [
                'message' => 'Please verify your email first. We sent a new code.',
                'needs_verification' => true,
                'email' => $user->email,
            ];

            if (config('app.debug')) {
                $payload['debug_otp'] = $code;
            }

            return response()->json($payload, 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Logged in.',
            'token' => $token,
            'user' => $this->userPayload($user),
        ]);
    }

    public function me(Request $request)
    {
        return response()->json([
            'user' => $this->userPayload($request->user()),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    private function userPayload(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
            'email_verified' => (bool) $user->email_verified_at,
        ];
    }
}
