
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

$name = trim((string) ($input['name'] ?? ''));
$type = trim((string) ($input['type'] ?? ''));
$location = trim((string) ($input['location'] ?? ''));
$latitude = $input['latitude'] ?? null;
$longitude = $input['longitude'] ?? null;

if ($name === '' || $type === '' || $location === '') {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'Nama, tipe, dan lokasi wajib diisi.'
    ]);
    exit;
}

if (
    !is_numeric($latitude) ||
    !is_numeric($longitude) ||
    !is_finite((float) $latitude) ||
    !is_finite((float) $longitude) ||
    (float) $latitude < -90 ||
    (float) $latitude > 90 ||
    (float) $longitude < -180 ||
    (float) $longitude > 180
) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'Koordinat latitude atau longitude tidak valid.'
    ]);
    exit;
}

try {
    $stmt = $pdo->prepare(
        'INSERT INTO institutions
            (name, type, location, latitude, longitude)
         VALUES (?, ?, ?, ?, ?)'
    );

    $stmt->execute([
        $name,
        $type,
        $location,
        (float) $latitude,
        (float) $longitude
    ]);

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Institusi berhasil ditambahkan.',
        'id' => (int) $pdo->lastInsertId()
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal menambahkan institusi.'
    ]);
}
