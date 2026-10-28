<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

function respond(int $s, array $d): void {
    http_response_code($s);
    echo json_encode($d, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method tidak diizinkan.']);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';

if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $authHeader, $matches)) {
    respond(401, ['success' => false, 'message' => 'Token tidak valid.']);
}

$tokenHash = hash('sha256', $matches[1]);
$stmt = $pdo->prepare(
    "SELECT u.id FROM api_tokens t
     JOIN users u ON u.id = t.user_id
     WHERE t.token_hash = ? AND t.expires_at > NOW() AND u.is_active = 1 LIMIT 1"
);
$stmt->execute([$tokenHash]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    respond(401, ['success' => false, 'message' => 'Sesi tidak valid.']);
}

$input = json_decode(file_get_contents('php://input'), true);
$fcmToken = trim($input['fcm_token'] ?? '');

if ($fcmToken === '') {
    respond(422, ['success' => false, 'message' => 'fcm_token tidak boleh kosong.']);
}

try {
    $stmt = $pdo->prepare(
        "INSERT INTO fcm_tokens (user_id, fcm_token)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE fcm_token = VALUES(fcm_token), updated_at = NOW()"
    );
    $stmt->execute([(int) $user['id'], $fcmToken]);

    respond(200, ['success' => true, 'message' => 'FCM token berhasil disimpan.']);
} catch (Throwable $e) {
    error_log('FCM SAVE TOKEN ERROR: ' . $e->getMessage());
    respond(500, ['success' => false, 'message' => 'Gagal menyimpan token.']);
}
