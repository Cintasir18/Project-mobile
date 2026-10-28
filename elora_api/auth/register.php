<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (
    preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}

header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    respond(405, ['success' => false, 'message' => 'Gunakan metode POST.']);
}

require_once __DIR__ . '/../config/database.php';

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    respond(400, ['success' => false, 'message' => 'Format JSON tidak valid.']);
}

$studentId      = trim($input['student_id'] ?? '');
$nama           = trim($input['nama'] ?? '');
$institutionId  = isset($input['institution_id']) ? (int) $input['institution_id'] : 0;
$password       = $input['password'] ?? '';

if ($studentId === '') {
    respond(422, ['success' => false, 'message' => 'NIS / ID Pelajar wajib diisi.']);
}
if (strlen($studentId) > 50) {
    respond(422, ['success' => false, 'message' => 'NIS / ID Pelajar terlalu panjang (maks 50 karakter).']);
}
if ($nama === '') {
    respond(422, ['success' => false, 'message' => 'Nama lengkap wajib diisi.']);
}
if (strlen($nama) > 100) {
    respond(422, ['success' => false, 'message' => 'Nama terlalu panjang (maks 100 karakter).']);
}
if ($institutionId <= 0) {
    respond(422, ['success' => false, 'message' => 'Institusi wajib dipilih.']);
}
if (!is_string($password) || $password === '') {
    respond(422, ['success' => false, 'message' => 'Password wajib diisi.']);
}
if (strlen($password) < 8) {
    respond(422, ['success' => false, 'message' => 'Password minimal 8 karakter.']);
}
if (strlen($password) > 4096) {
    respond(422, ['success' => false, 'message' => 'Password terlalu panjang.']);
}

try {
    $pdo->beginTransaction();

    $checkId = $pdo->prepare('SELECT id FROM users WHERE student_id = ? LIMIT 1');
    $checkId->execute([$studentId]);
    if ($checkId->fetch()) {
        $pdo->rollBack();
        respond(409, ['success' => false, 'message' => 'NIS / ID Pelajar ini sudah terdaftar.']);
    }

    $stmtInst = $pdo->prepare('SELECT name FROM institutions WHERE id = ? AND is_active = 1 LIMIT 1');
    $stmtInst->execute([$institutionId]);
    $institution = $stmtInst->fetch();

    if (!$institution) {
        $pdo->rollBack();
        respond(404, ['success' => false, 'message' => 'Institusi tidak ditemukan atau tidak aktif.']);
    }

    $institutionName = $institution['name'];

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);

    $insert = $pdo->prepare(
        'INSERT INTO users (nama, student_id, password_hash, institution, role, is_active)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $insert->execute([
        $nama,
        $studentId,
        $passwordHash,
        $institutionName,
        'student',
        1,
    ]);

    $pdo->commit();

    respond(201, [
        'success' => true,
        'message' => 'Registrasi berhasil! Silakan login dengan NIS dan password kamu.',
    ]);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log('ELORA REGISTER ERROR: ' . $e->getMessage());

    respond(500, [
        'success' => false,
        'message' => 'Registrasi gagal karena kesalahan server. Silakan coba lagi.',
    ]);
}
