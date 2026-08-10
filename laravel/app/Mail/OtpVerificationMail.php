<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class OtpVerificationMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $name,
        public string $otp,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Your Amora Florals verification code',
        );
    }

    public function content(): Content
    {
        return new Content(
            htmlString: <<<HTML
                <div style="font-family: Georgia, serif; color: #4A3538; max-width: 480px; margin: 0 auto;">
                    <h2 style="color: #C97B85;">Amora Florals</h2>
                    <p>Hi {$this->name},</p>
                    <p>Use this code to verify your customer account:</p>
                    <p style="font-size: 32px; letter-spacing: 8px; font-weight: bold; color: #C97B85;">{$this->otp}</p>
                    <p>This code expires in <strong>10 minutes</strong>.</p>
                    <p style="color: #8a6f72;">If you did not sign up, you can ignore this email.</p>
                </div>
            HTML,
        );
    }
}
