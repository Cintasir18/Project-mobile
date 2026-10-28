
<?php

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
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Format JSON tidak valid.'
    ]);
    exit;
}

$id = filter_var($input['id'] ?? null, FILTER_VALIDATE_INT);

if (!$id || $id < 1) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'ID institusi tidak valid.'
    ]);
    exit;
}

try {
    $stmt = $pdo->prepare(
        'UPDATE institutions
         SET is_active = 0
         WHERE id = ? AND is_active = 1'
    );

    $stmt->execute([$id]);

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Institusi tidak ditemukan atau sudah nonaktif.'
        ]);
        exit;
    }

    echo json_encode([
        'success' => true,
        'message' => 'Institusi berhasil dinonaktifkan.'
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal menonaktifkan institusi.'
    ]);
}
