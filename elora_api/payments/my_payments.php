<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

$allowedOrigins = [
    'http://localhost',
    'http://127.0.0.1',
];

if (
    preg_match('/^http:\/\/localhost:\d+$/', $origin) ||
    preg_match('/^http:\/\/127\.0\.0\.1:\d+$/', $origin) ||
    in_array($origin, $allowedOrigins, true)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

function respond(
    int $httpCode,
    array $payload
): void {
    http_response_code($httpCode);

    echo json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );

    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET, OPTIONS');

    respond(405, [
        'success' => false,
        'message' => 'Method tidak diizinkan.',
    ]);
}

try {
    require_once __DIR__ . '/../config/database.php';

    if (!isset($pdo) || !($pdo instanceof PDO)) {
        throw new RuntimeException(
            'Koneksi database PDO tidak tersedia.'
        );
    }

    $pdo->setAttribute(
        PDO::ATTR_ERRMODE,
        PDO::ERRMODE_EXCEPTION
    );

    $authorization = '';

    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strtolower($name) === 'authorization') {
                $authorization = $value;
                break;
            }
        }
    }

    if ($authorization === '') {
        $authorization =
            $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    }

    if ($authorization === '') {
        $authorization =
            $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }

    if (
        !preg_match(
            '/^Bearer\s+(.+)$/i',
            trim($authorization),
            $matches
        )
    ) {
        respond(401, [
            'success' => false,
            'message' => 'Token tidak ditemukan.',
        ]);
    }

    $token = trim($matches[1]);

    $tokenHash = hash('sha256', $token);

    $stmt = $pdo->prepare(
        "SELECT u.id, u.nama, u.institution
         FROM api_tokens t
         INNER JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = ?
           AND t.expires_at > NOW()
           AND u.is_active = 1
           AND LOWER(u.role) = 'student'
         LIMIT 1"
    );

    $stmt->execute([$tokenHash]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respond(401, [
            'success' => false,
            'message' =>
                'Sesi tidak valid atau akun tidak aktif.',
        ]);
    }

    $userId = (int) $user['id'];

    $stmt = $pdo->prepare(
        "SELECT
            id,
            bill_type,
            billing_month,
            billing_year,
            amount,
            paid_amount,
            due_date,
            paid_at,
            status,
            notes
         FROM bills
         WHERE user_id = ?
         ORDER BY billing_year DESC, billing_month DESC, id DESC"
    );

    $stmt->execute([$userId]);

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $payments = [];

    $totalAmount = 0.0;
    $totalPaid = 0.0;
    $totalOutstanding = 0.0;
    $unpaidCount = 0;

    foreach ($rows as $row) {
        $amount = (float) $row['amount'];
        $paidAmount = (float) $row['paid_amount'];

        $remainingAmount = max(
            0,
            $amount - $paidAmount
        );

        if ($remainingAmount <= 0) {
            $status = 'paid';
        } elseif ($paidAmount > 0) {
            $status = 'partial';
        } else {
            $status = 'unpaid';
        }

        $month = (int) $row['billing_month'];
        $year = (int) $row['billing_year'];

        $period = sprintf(
            '%04d-%02d',
            $year,
            $month
        );

        $payments[] = [
            'id' => (int) $row['id'],
            'period' => $period,
            'billing_month' => $month,
            'billing_year' => $year,
            'bill_type' => $row['bill_type'],
            'amount' => $amount,
            'paid_amount' => $paidAmount,
            'remaining_amount' => $remainingAmount,
            'due_date' => $row['due_date'],
            'paid_at' => $row['paid_at'],
            'status' => $status,
            'notes' => $row['notes'],
        ];

        $totalAmount += $amount;
        $totalPaid += $paidAmount;
        $totalOutstanding += $remainingAmount;

        if ($remainingAmount > 0) {
            $unpaidCount++;
        }
    }

    respond(200, [
        'success' => true,
        'message' => 'Riwayat pembayaran berhasil diambil.',
        'data' => $payments,
        'summary' => [
            'total_bills' => count($payments),
            'total_amount' => round($totalAmount, 2),
            'total_paid' => round($totalPaid, 2),
            'total_outstanding' => round(
                $totalOutstanding,
                2
            ),
            'unpaid_count' => $unpaidCount,
        ],
    ]);

} catch (Throwable $e) {
    error_log(
        'ELORA my_payments API error: ' . $e->getMessage()
    );

    respond(500, [
        'success' => false,
        'message' =>
            'Terjadi kesalahan pada server pembayaran.',
    ]);
}
