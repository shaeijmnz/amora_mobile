<?php

use App\Http\Controllers\Api\Admin\AuthController as AdminAuthController;
use App\Http\Controllers\Api\Admin\CustomerController as AdminCustomerController;
use App\Http\Controllers\Api\Admin\CustomRequestController as AdminCustomRequestController;
use App\Http\Controllers\Api\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Api\Admin\DeliveryController as AdminDeliveryController;
use App\Http\Controllers\Api\Admin\InventoryController as AdminInventoryController;
use App\Http\Controllers\Api\Admin\MessageController as AdminMessageController;
use App\Http\Controllers\Api\Admin\NotificationController as AdminNotificationController;
use App\Http\Controllers\Api\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\Admin\ProductController as AdminProductController;
use App\Http\Controllers\Api\Admin\ReportController as AdminReportController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomRequestController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PayMongoWebhookController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'ok' => true,
        'app' => 'Amora Florals API',
    ]);
});

// Customer auth
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/verify-otp', [AuthController::class, 'verifyOtp']);
Route::post('/resend-otp', [AuthController::class, 'resendOtp']);

// Public catalog (customer + admin can read)
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/{product}', [ProductController::class, 'show']);

// PayMongo webhooks (no auth; optional signature verify)
Route::post('/paymongo/webhook', PayMongoWebhookController::class);

// Admin auth
Route::post('/admin/login', [AdminAuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Customer orders
    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::post('/orders/checkout', [OrderController::class, 'checkout']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::get('/orders/{order}/payment-status', [OrderController::class, 'paymentStatus']);

    // Customer custom arrangement requests
    Route::get('/custom-requests', [CustomRequestController::class, 'index']);
    Route::post('/custom-requests', [CustomRequestController::class, 'store']);

    Route::get('/messages', [MessageController::class, 'show']);
    Route::post('/messages', [MessageController::class, 'store']);

    // Admin API
    Route::prefix('admin')->middleware('admin')->group(function () {
        Route::get('/me', [AdminAuthController::class, 'me']);
        Route::post('/logout', [AdminAuthController::class, 'logout']);
        Route::get('/dashboard', [AdminDashboardController::class, 'summary']);
        Route::get('/customers', [AdminCustomerController::class, 'index']);
        Route::get('/customers/{user}', [AdminCustomerController::class, 'show']);
        Route::get('/products', [AdminProductController::class, 'index']);
        Route::post('/products/upload-image', [AdminProductController::class, 'uploadImage']);
        Route::post('/products', [AdminProductController::class, 'store']);
        Route::get('/products/{product}', [AdminProductController::class, 'show']);
        Route::patch('/products/{product}', [AdminProductController::class, 'update']);
        Route::post('/products/{product}/duplicate', [AdminProductController::class, 'duplicate']);
        Route::get('/orders', [AdminOrderController::class, 'index']);
        Route::get('/orders/{order}', [AdminOrderController::class, 'show']);
        Route::patch('/orders/{order}', [AdminOrderController::class, 'updateStatus']);
        Route::get('/deliveries', [AdminDeliveryController::class, 'index']);
        Route::get('/deliveries/{delivery}', [AdminDeliveryController::class, 'show']);
        Route::patch('/deliveries/{delivery}', [AdminDeliveryController::class, 'update']);
        Route::get('/inventory', [AdminInventoryController::class, 'index']);
        Route::patch('/inventory/{item}', [AdminInventoryController::class, 'update']);
        Route::get('/custom-requests', [AdminCustomRequestController::class, 'index']);
        Route::get('/custom-requests/{customRequest}', [AdminCustomRequestController::class, 'show']);
        Route::patch('/custom-requests/{customRequest}', [AdminCustomRequestController::class, 'update']);
        Route::get('/reports', [AdminReportController::class, 'index']);
        Route::get('/messages/unread-count', [AdminMessageController::class, 'unreadCount']);
        Route::get('/messages', [AdminMessageController::class, 'index']);
        Route::get('/messages/{conversation}', [AdminMessageController::class, 'show']);
        Route::post('/messages/{conversation}', [AdminMessageController::class, 'store']);

        Route::get('/notifications', [AdminNotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [AdminNotificationController::class, 'unreadCount']);
        Route::post('/notifications/read-all', [AdminNotificationController::class, 'markAllRead']);
        Route::patch('/notifications/{notification}/read', [AdminNotificationController::class, 'markRead']);
        Route::delete('/notifications/{notification}', [AdminNotificationController::class, 'destroy']);
    });
});
