
<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Gunakan metode GET.'
    ]);
    exit;
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

requireAdmin($pdo);

try {
    $stmt = $pdo->prepare(
        "SELECT id, nama, email, student_id, institution, role,
                is_active, created_at
         FROM users
         WHERE LOWER(role) = 'student'
         ORDER BY nama ASC"
    );

    $stmt->execute();
    $students = $stmt->fetchAll();

    foreach ($students as &$student) {
        $student['id'] = (int) $student['id'];
        $student['is_active'] = (bool) $student['is_active'];
    }
    unset($student);

    echo json_encode([
        'success' => true,
        'message' => 'Data siswa berhasil diambil.',
        'data' => $students
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    error_log('ELORA STUDENT LIST ERROR: ' . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil data siswa.'
    ]);
}
