
<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Gunakan metode POST.'
    ]);
    exit;
}

require_once __DIR__ . '/../config/database.php';

$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = '';

foreach ($headers as $key => $value) {
    if (strtolower($key) === 'authorization') {
        $authHeader = $value;
        break;
    }
}

if ($authHeader === '') {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
}

if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Token tidak ditemukan atau tidak valid.'
    ]);
    exit;
}

$tokenHash = hash('sha256', $matches[1]);

try {
    $stmt = $pdo->prepare(
        'DELETE FROM api_tokens WHERE token_hash = ?'
    );
    $stmt->execute([$tokenHash]);

    if ($stmt->rowCount() === 0) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Sesi tidak ditemukan atau sudah berakhir.'
        ]);
        exit;
    }

    echo json_encode([
        'success' => true,
        'message' => 'Logout berhasil.'
    ]);

} catch (PDOException $e) {
    error_log('ELORA LOGOUT ERROR: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan pada server.'
    ]);
}
