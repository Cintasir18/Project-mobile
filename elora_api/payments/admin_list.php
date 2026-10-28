<?php

declare(strict_types=1);

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode(
        $data,
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
        'message' => 'Gunakan metode GET.',
    ]);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

try {
    $sql = "
        SELECT
            b.id AS payment_id,
            b.id AS bill_id,
            b.user_id,
            b.institution_id,
            b.billing_month,
            b.billing_year,
            b.bill_type,
            b.amount,
            b.paid_amount,
            b.due_date,
            b.paid_at,
            b.status,
            b.notes,

            u.nama,
            u.student_id,
            u.institution

        FROM bills b

        INNER JOIN users u
            ON u.id = b.user_id

        WHERE LOWER(u.role) = 'student'

        ORDER BY
            b.billing_year DESC,
            b.billing_month DESC,
            u.nama ASC,
            b.id DESC
    ";

    $stmt = $pdo->query($sql);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $payments = [];

    $totalAmount = 0.0;
    $totalPaid = 0.0;
    $totalOutstanding = 0.0;
    $unpaidCount = 0;

    foreach ($rows as $row) {
        $amount = (float) $row['amount'];
        $paidAmount = (float) $row['paid_amount'];

        $remainingAmount = max(0, $amount - $paidAmount);

        if ($remainingAmount <= 0) {
            $status = 'paid';
        } elseif ($paidAmount > 0) {
            $status = 'partial';
        } else {
            $status = 'unpaid';
        }

        $month = (int) $row['billing_month'];
        $year = (int) $row['billing_year'];

        $period = sprintf('%04d-%02d', $year, $month);

        $payments[] = [
            'payment_id' => (int) $row['payment_id'],
            'bill_id' => (int) $row['bill_id'],
            'user_id' => (int) $row['user_id'],

            'institution_id' => $row['institution_id'] !== null
                ? (int) $row['institution_id']
                : null,

            'nama' => $row['nama'],
            'student_id' => $row['student_id'],
            'institution' => $row['institution'],

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
        'message' => 'Data pembayaran berhasil diambil.',
        'data' => $payments,
        'summary' => [
            'total_bills' => count($payments),
            'total_amount' => round($totalAmount, 2),
            'total_paid' => round($totalPaid, 2),
            'total_outstanding' => round($totalOutstanding, 2),
            'unpaid_count' => $unpaidCount,
        ],
    ]);

} catch (Throwable $e) {
    error_log(
        'ELORA ADMIN PAYMENTS ERROR: ' . $e->getMessage()
    );

    respond(500, [
        'success' => false,
        'message' => 'Gagal mengambil data pembayaran.',
    ]);
}
