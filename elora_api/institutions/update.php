
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
$name = trim((string) ($input['name'] ?? ''));
$type = trim((string) ($input['type'] ?? ''));
$location = trim((string) ($input['location'] ?? ''));
$latitude = $input['latitude'] ?? null;
$longitude = $input['longitude'] ?? null;

if (!$id || $id < 1) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'ID institusi tidak valid.'
    ]);
    exit;
}

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
        'UPDATE institutions
         SET name = ?,
             type = ?,
             location = ?,
             latitude = ?,
             longitude = ?
         WHERE id = ? AND is_active = 1'
    );

    $stmt->execute([
        $name,
        $type,
        $location,
        (float) $latitude,
        (float) $longitude,
        $id
    ]);

    if ($stmt->rowCount() === 0) {
        $check = $pdo->prepare(
            'SELECT id, name, type, location, latitude, longitude
             FROM institutions
             WHERE id = ? AND is_active = 1'
        );
        $check->execute([$id]);
        $existing = $check->fetch();

        if (!$existing) {
            http_response_code(404);
            echo json_encode([
                'success' => false,
                'message' => 'Institusi tidak ditemukan atau sudah nonaktif.'
            ]);
            exit;
        }

    }

    echo json_encode([
        'success' => true,
        'message' => 'Data institusi berhasil diperbarui.'
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal memperbarui data institusi.'
    ]);
}
