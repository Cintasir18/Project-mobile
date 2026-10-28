
<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(int $code, array $data): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, [
        'success' => false,
        'message' => 'Gunakan metode POST.'
    ]);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    respond(400, [
        'success' => false,
        'message' => 'Format JSON tidak valid.'
    ]);
}

$userId = filter_var(
    $input['user_id'] ?? null,
    FILTER_VALIDATE_INT
);

$isActive = $input['is_active'] ?? null;

if (!$userId || !in_array($isActive, [0, 1, '0', '1'], true)) {
    respond(400, [
        'success' => false,
        'message' => 'ID siswa atau status tidak valid.'
    ]);
}

try {
    $check = $pdo->prepare(
        "SELECT id FROM users
         WHERE id = ? AND LOWER(role) = 'student'"
    );
    $check->execute([$userId]);

    if (!$check->fetch()) {
        respond(404, [
            'success' => false,
            'message' => 'Data siswa tidak ditemukan.'
        ]);
    }

    $activeValue = (int) $isActive;

    $stmt = $pdo->prepare(
        "UPDATE users
         SET is_active = ?
         WHERE id = ? AND LOWER(role) = 'student'"
    );

    $stmt->execute([$activeValue, $userId]);

    respond(200, [
        'success' => true,
        'message' => $activeValue === 1
            ? 'Akun siswa berhasil diaktifkan.'
            : 'Akun siswa berhasil dinonaktifkan.',
        'data' => [
            'user_id' => (int) $userId,
            'is_active' => $activeValue
        ]
    ]);
} catch (PDOException $e) {
    error_log('ELORA UPDATE STUDENT STATUS: ' . $e->getMessage());

    respond(500, [
        'success' => false,
        'message' => 'Gagal memperbarui status akun siswa.'
    ]);
}
