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
header('Access-Control-Allow-Methods: GET, OPTIONS');
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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET, OPTIONS');
    respond(405, [
        'success' => false,
        'message' => 'Metode request tidak diizinkan.',
    ]);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

try {
    $user = requireUser($pdo);
} catch (Throwable $e) {
    respond(401, ['success' => false, 'message' => 'Autentikasi gagal.']);
}

$role = strtolower(trim((string) ($user['role'] ?? '')));

try {
    if ($role === 'admin') {
        $stmt = $pdo->prepare(
            'SELECT pc.*
             FROM payment_chain pc
             ORDER BY pc.block_index ASC'
        );
        $stmt->execute();
    } else {
        $stmt = $pdo->prepare(
            'SELECT pc.*
             FROM payment_chain pc
             WHERE pc.user_id = :uid
             ORDER BY pc.block_index ASC'
        );
        $stmt->execute([':uid' => (int) $user['id']]);
    }

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $chainValid = count($rows) > 0 ? true : null;
    $blocks     = [];

    foreach ($rows as $i => $row) {
        $recalcHash = hash(
            'sha256',
            $row['block_index']
            . $row['bill_id']
            . $row['student_id']
            . $row['period']
            . $row['old_status']
            . $row['new_status']
            . $row['changed_by_id']
            . $row['block_timestamp']
            . $row['previous_hash']
        );

        $hashMatch  = hash_equals($recalcHash, (string) $row['block_hash']);

        $prevOk = true;
        if ($role === 'admin' && $i > 0) {
            $prevOk = hash_equals(
                (string) $blocks[$i - 1]['block_hash'],
                (string) $row['previous_hash']
            );
        }

        $isValid = $hashMatch && $prevOk;

        if (!$isValid) {
            $chainValid = false;
        }

        $blocks[] = [
            'id'              => (int)    $row['id'],
            'block_index'     => (int)    $row['block_index'],
            'bill_id'         => (int)    $row['bill_id'],
            'user_id'         => (int)    $row['user_id'],
            'student_id'      => (string) $row['student_id'],
            'nama'            => (string) $row['nama'],
            'period'          => (string) $row['period'],
            'amount'          => (string) $row['amount'],
            'old_status'      => (string) $row['old_status'],
            'new_status'      => (string) $row['new_status'],
            'changed_by_id'   => (int)    $row['changed_by_id'],
            'changed_by_name' => (string) $row['changed_by_name'],
            'timestamp'       => (string) $row['block_timestamp'],
            'previous_hash'   => (string) $row['previous_hash'],
            'block_hash'      => (string) $row['block_hash'],
            'is_valid'        => $isValid,
        ];
    }

    respond(200, [
        'success'      => true,
        'chain_valid'  => $chainValid,
        'chain_empty'  => count($blocks) === 0,
        'total_blocks' => count($blocks),
        'data'         => $blocks,
    ]);

} catch (Throwable $e) {
    error_log('ELORA CHAIN ERROR: ' . $e->getMessage());
    respond(500, [
        'success' => false,
        'message' => 'Gagal mengambil data blockchain.',
    ]);
}
