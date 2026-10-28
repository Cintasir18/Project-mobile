<?php

declare(strict_types=1);

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $config = $pdo->query("SELECT amount, due_day FROM spp_config ORDER BY id DESC LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    respond(200, [
        'success'  => true,
        'amount'   => $config ? (float) $config['amount'] : 500000.0,
        'due_day'  => $config ? (int) $config['due_day']  : 10,
    ]);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!is_array($input)) {
        respond(400, ['success' => false, 'message' => 'Format JSON tidak valid.']);
    }

    $amount  = isset($input['amount'])  ? (float) $input['amount']  : null;
    $dueDay  = isset($input['due_day']) ? (int)   $input['due_day'] : null;

    if ($amount !== null && $amount <= 0) {
        respond(422, ['success' => false, 'message' => 'Nominal SPP harus lebih dari 0.']);
    }
    if ($dueDay !== null && ($dueDay < 1 || $dueDay > 28)) {
        respond(422, ['success' => false, 'message' => 'Hari jatuh tempo harus antara 1–28.']);
    }

    $count = (int) $pdo->query("SELECT COUNT(*) FROM spp_config")->fetchColumn();
    if ($count === 0) {
        $pdo->exec("INSERT INTO spp_config (amount, due_day) VALUES (" . ($amount ?? 500000) . ", " . ($dueDay ?? 10) . ")");
    } else {
        $sets = [];
        $params = [];
        if ($amount !== null)  { $sets[] = 'amount = ?';  $params[] = $amount; }
        if ($dueDay !== null)  { $sets[] = 'due_day = ?'; $params[] = $dueDay; }
        if (!empty($sets)) {
            $pdo->prepare("UPDATE spp_config SET " . implode(', ', $sets))->execute($params);
        }
    }

    respond(200, ['success' => true, 'message' => 'Konfigurasi SPP berhasil diperbarui.']);
}

respond(405, ['success' => false, 'message' => 'Method tidak diizinkan.']);
