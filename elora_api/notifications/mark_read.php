<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed.']); exit;
}

if (!function_exists('respond')) {
    function respond(int $s, array $d): void {
        http_response_code($s);
        echo json_encode($d, JSON_UNESCAPED_UNICODE);
        exit;
    }
}

$user = requireUser($pdo);

$pdo->exec('CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT \'general\',
    target ENUM(\'all\',\'user\') NOT NULL DEFAULT \'all\',
    target_user_id INT NULL,
    created_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
)');
$pdo->exec('CREATE TABLE IF NOT EXISTS notification_reads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    notification_id INT NOT NULL,
    user_id INT NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notif_user (notification_id, user_id),
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$id    = (int) ($input['notification_id'] ?? 0);
if ($id <= 0) {
    respond(422, ['success' => false, 'message' => 'notification_id tidak valid.']); exit;
}

try {
    $uid = (int) $user['id'];
    $chk = $pdo->prepare(
        'SELECT 1 FROM notifications WHERE id = ? AND (target = \'all\' OR target_user_id = ?) LIMIT 1'
    );
    $chk->execute([$id, $uid]);
    if (!$chk->fetch()) {
        respond(404, ['success' => false, 'message' => 'Notifikasi tidak ditemukan.']); exit;
    }
    $upsert = $pdo->prepare(
        'INSERT INTO notification_reads (notification_id, user_id) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP'
    );
    $upsert->execute([$id, $uid]);
    respond(200, ['success' => true, 'message' => 'Notifikasi ditandai dibaca.']);
} catch (Throwable $e) {
    error_log('MARK READ ERROR: ' . $e->getMessage());
    respond(500, ['success' => false, 'message' => 'Gagal menandai notifikasi.']);
}
