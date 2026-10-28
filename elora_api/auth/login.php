
<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    preg_match(
        '/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/',
        $origin
    )
) {
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

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Format JSON tidak valid.'
    ]);
    exit;
}

$identifier = trim($input['student_id'] ?? '');
$password = $input['password'] ?? '';

if (
    $identifier === '' ||
    strlen($identifier) > 150 ||
    !is_string($password) ||
    $password === '' ||
    strlen($password) > 4096
) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'Nomor pelajar/email dan password harus diisi.'
    ]);
    exit;
}

try {
    $stmt = $pdo->prepare(
        'SELECT id, nama, email, password_hash,
                student_id, institution, role, is_active
         FROM users
         WHERE student_id = ? OR email = ?
         LIMIT 1'
    );

    $stmt->execute([
        $identifier,
        strtolower($identifier)
    ]);

    $user = $stmt->fetch();

    if (
        !$user ||
        !password_verify($password, $user['password_hash'])
    ) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Nomor pelajar/email atau password salah.'
        ]);
        exit;
    }

    if ((int) $user['is_active'] !== 1) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Akun kamu telah dinonaktifkan. Hubungi admin.'
        ]);
        exit;
    }

    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);

    $save = $pdo->prepare(
        'INSERT INTO api_tokens
         (user_id, token_hash, expires_at)
         VALUES (?, ?, NOW() + INTERVAL 1 HOUR)'
    );

    $save->execute([
        $user['id'],
        $tokenHash,
    ]);

    unset($user['password_hash'], $user['is_active']);

    http_response_code(200);

    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil.',
        'token'   => $token,
        'user'    => $user
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan pada server.'
    ]);
}
