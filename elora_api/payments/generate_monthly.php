<?php

declare(strict_types=1);

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Gunakan metode POST.']);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    respond(400, ['success' => false, 'message' => 'Format JSON tidak valid.']);
}

$month = isset($input['month']) ? (int) $input['month'] : 0;
$year  = isset($input['year'])  ? (int) $input['year']  : 0;

if ($month < 1 || $month > 12) {
    respond(422, ['success' => false, 'message' => 'Bulan tidak valid (1–12).']);
}
if ($year < 2020 || $year > 2100) {
    respond(422, ['success' => false, 'message' => 'Tahun tidak valid.']);
}

$customAmount = isset($input['amount']) ? (float) $input['amount'] : null;
if ($customAmount !== null && $customAmount <= 0) {
    respond(422, ['success' => false, 'message' => 'Nominal SPP harus lebih dari 0.']);
}

try {
    $pdo->beginTransaction();

    $config = $pdo->query("SELECT amount, due_day FROM spp_config ORDER BY id DESC LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $sppAmount = $customAmount ?? (float) ($config['amount'] ?? 500000);
    $dueDay    = (int) ($config['due_day'] ?? 10);

    $maxDay  = (int) date('t', mktime(0, 0, 0, $month, 1, $year));
    $dueDay  = min($dueDay, $maxDay);
    $dueDate = sprintf('%04d-%02d-%02d', $year, $month, $dueDay);

    $students = $pdo->query("SELECT id FROM users WHERE role = 'student' AND is_active = 1")->fetchAll(PDO::FETCH_ASSOC);

    if (empty($students)) {
        $pdo->rollBack();
        respond(404, ['success' => false, 'message' => 'Tidak ada siswa aktif yang terdaftar.']);
    }

    $stmt = $pdo->prepare("
        INSERT IGNORE INTO bills
            (user_id, bill_type, billing_month, billing_year, amount, paid_amount, due_date, status)
        VALUES
            (?, 'SPP', ?, ?, ?, 0, ?, 'unpaid')
    ");

    $inserted = 0;
    $skipped  = 0;

    foreach ($students as $student) {
        $stmt->execute([$student['id'], $month, $year, $sppAmount, $dueDate]);
        if ($stmt->rowCount() > 0) {
            $inserted++;
        } else {
            $skipped++;
        }
    }

    $pdo->commit();

    $monthNames = [
        1=>'Januari',2=>'Februari',3=>'Maret',4=>'April',
        5=>'Mei',6=>'Juni',7=>'Juli',8=>'Agustus',
        9=>'September',10=>'Oktober',11=>'November',12=>'Desember',
    ];

    respond(200, [
        'success'  => true,
        'message'  => "Tagihan SPP {$monthNames[$month]} {$year} berhasil digenerate.",
        'inserted' => $inserted,
        'skipped'  => $skipped,
        'period'   => sprintf('%04d-%02d', $year, $month),
        'amount'   => $sppAmount,
        'due_date' => $dueDate,
    ]);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('ELORA GENERATE MONTHLY ERROR: ' . $e->getMessage());
    respond(500, ['success' => false, 'message' => 'Gagal generate tagihan: ' . $e->getMessage()]);
}
