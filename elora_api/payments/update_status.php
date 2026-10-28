<?php

declare(strict_types=1);

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/192\.168\.\d+\.\d+(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/10\.\d+\.\d+\.\d+(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d+\.\d+(:\d+)?$/', $origin)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

function respond(int $code, array $data): void
{
    http_response_code($code);
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST, OPTIONS');

    respond(405, [
        'success' => false,
        'message' => 'Metode request tidak diizinkan.',
    ]);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

$admin = requireAdmin($pdo);

$input = json_decode(
    file_get_contents('php://input'),
    true
);

if (!is_array($input)) {
    respond(400, [
        'success' => false,
        'message' => 'Format JSON tidak valid.',
    ]);
}

$paymentId = filter_var(
    $input['payment_id'] ?? null,
    FILTER_VALIDATE_INT
);

$status = strtolower(
    trim((string) ($input['status'] ?? ''))
);

if (
    !$paymentId ||
    !in_array($status, ['paid', 'unpaid'], true)
) {
    respond(400, [
        'success' => false,
        'message' => 'ID pembayaran atau status tidak valid.',
    ]);
}

try {
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        'SELECT b.id, b.amount, b.paid_amount, b.status,
                b.billing_month, b.billing_year,
                u.id AS owner_user_id,
                u.student_id AS owner_student_id,
                u.nama AS owner_nama
         FROM bills b
         JOIN users u ON u.id = b.user_id
         WHERE b.id = ?
         LIMIT 1
         FOR UPDATE'
    );

    $stmt->execute([$paymentId]);
    $bill = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$bill) {
        $pdo->rollBack();

        respond(404, [
            'success' => false,
            'message' => 'Data tagihan tidak ditemukan.',
        ]);
    }

    $amount    = (float) $bill['amount'];
    $oldStatus = (string) $bill['status'];

    $billingMonth = str_pad((string)(int)$bill['billing_month'], 2, '0', STR_PAD_LEFT);
    $billingYear  = (string)(int)$bill['billing_year'];
    $period       = $billingYear . '-' . $billingMonth;

    if ($status === 'paid') {
        $paidAmount = $amount;
        $paidAt     = date('Y-m-d H:i:s');
    } else {
        $paidAmount = 0;
        $paidAt     = null;
    }

    $blockTimestamp = date('Y-m-d H:i:s');

    $stmt = $pdo->prepare(
        'UPDATE bills
         SET status = :status,
             paid_amount = :paid_amount,
             paid_at = :paid_at,
             updated_at = NOW()
         WHERE id = :id'
    );

    $stmt->execute([
        ':status'      => $status,
        ':paid_amount' => $paidAmount,
        ':paid_at'     => $paidAt,
        ':id'          => $paymentId,
    ]);

    $prevStmt = $pdo->query(
        'SELECT block_index, block_hash
         FROM payment_chain
         ORDER BY block_index DESC
         LIMIT 1
         FOR UPDATE'
    );
    $prevRow      = $prevStmt->fetch(PDO::FETCH_ASSOC);
    $blockIndex   = $prevRow ? ((int) $prevRow['block_index'] + 1) : 1;
    $previousHash = $prevRow ? (string) $prevRow['block_hash'] : str_repeat('0', 64);

    $blockHash = hash(
        'sha256',
        $blockIndex
        . $paymentId
        . $bill['owner_student_id']
        . $period
        . $oldStatus
        . $status
        . $admin['id']
        . $blockTimestamp
        . $previousHash
    );

    $chainStmt = $pdo->prepare(
        'INSERT INTO payment_chain
         (block_index, bill_id, user_id, student_id, nama, period,
          amount, old_status, new_status, changed_by_id, changed_by_name,
          block_timestamp, previous_hash, block_hash)
         VALUES
         (:block_index, :bill_id, :user_id, :student_id, :nama, :period,
          :amount, :old_status, :new_status, :changed_by_id, :changed_by_name,
          :block_timestamp, :previous_hash, :block_hash)'
    );

    $chainStmt->execute([
        ':block_index'     => $blockIndex,
        ':bill_id'         => (int) $paymentId,
        ':user_id'         => (int) $bill['owner_user_id'],
        ':student_id'      => (string) $bill['owner_student_id'],
        ':nama'            => (string) $bill['owner_nama'],
        ':period'          => $period,
        ':amount'          => $amount,
        ':old_status'      => $oldStatus,
        ':new_status'      => $status,
        ':changed_by_id'   => (int) $admin['id'],
        ':changed_by_name' => (string) $admin['nama'],
        ':block_timestamp' => $blockTimestamp,
        ':previous_hash'   => $previousHash,
        ':block_hash'      => $blockHash,
    ]);

    $pdo->commit();

    respond(200, [
        'success' => true,
        'message' => $status === 'paid'
            ? 'Tagihan berhasil ditandai lunas.'
            : 'Status tagihan berhasil dikembalikan menjadi belum lunas.',
        'data' => [
            'payment_id'       => (int) $paymentId,
            'status'           => $status,
            'amount'           => $amount,
            'paid_amount'      => $paidAmount,
            'remaining_amount' => max(0, $amount - $paidAmount),
            'paid_at'          => $paidAt,
        ],
    ]);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log(
        'ELORA UPDATE PAYMENT STATUS ERROR: '
        . $e->getMessage()
    );

    respond(500, [
        'success' => false,
        'message' => 'Gagal memperbarui status pembayaran.',
    ]);
}
