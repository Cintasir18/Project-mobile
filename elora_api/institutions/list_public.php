<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    preg_match('/^http:\/\/localhost(:\d+)?$/', $origin) ||
    preg_match('/^http:\/\/127\.0\.0\.1(:\d+)?$/', $origin)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method tidak diizinkan.', 'data' => []]);
    exit;
}

try {
    require_once __DIR__ . '/../config/database.php';

    $stmt = $pdo->query("
        SELECT id, name, type, location
        FROM institutions
        WHERE is_active = 1
        ORDER BY name ASC
    ");

    $institutions = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($institutions as &$row) {
        $row['id'] = (int) $row['id'];
    }
    unset($row);

    echo json_encode([
        'success' => true,
        'data'    => $institutions,
    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {
    http_response_code(500);
    error_log('Institution list_public error: ' . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Gagal mengambil daftar institusi.', 'data' => []]);
}
