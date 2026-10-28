
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
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method tidak diizinkan.',
        'data' => [],
    ]);
    exit;
}

try {
    require_once __DIR__ . '/../config/database.php';

    $stmt = $pdo->query("
        SELECT
            id,
            name,
            type,
            location,
            latitude,
            longitude,
            is_active,
            created_at,
            updated_at
        FROM institutions
        WHERE is_active = 1
        ORDER BY name ASC
    ");

    $institutions = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($institutions as &$institution) {
        $institution['id'] = (int) $institution['id'];
        $institution['latitude'] = $institution['latitude'] !== null
            ? (float) $institution['latitude']
            : null;
        $institution['longitude'] = $institution['longitude'] !== null
            ? (float) $institution['longitude']
            : null;
        $institution['is_active'] = (bool) $institution['is_active'];
    }
    unset($institution);

    echo json_encode([
        'success' => true,
        'message' => 'Daftar institusi berhasil diambil.',
        'data' => $institutions,
    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {
    http_response_code(500);

    error_log('Institution list error: ' . $e->getMessage());

    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil daftar institusi.',
        'data' => [],
    ]);
}
