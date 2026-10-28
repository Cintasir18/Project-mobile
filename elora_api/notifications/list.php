<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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

try {
    $uid  = (int) $user['id'];
    $stmt = $pdo->prepare(
        'SELECT n.id, n.title, n.body AS message, n.type, n.created_at,
                (nr.read_at IS NOT NULL) AS is_read
         FROM notifications n
         LEFT JOIN notification_reads nr
           ON nr.notification_id = n.id AND nr.user_id = :uid
         WHERE n.target = \'all\' OR (n.target = \'user\' AND n.target_user_id = :uid2)
         ORDER BY n.created_at DESC
         LIMIT 200'
    );
    $stmt->execute([':uid' => $uid, ':uid2' => $uid]);
    $rows = $stmt->fetchAll();
    $data = array_map(function ($row) {
        return [
            'id'         => (int)  $row['id'],
            'title'      => $row['title'],
            'message'    => $row['message'],
            'type'       => $row['type'],
            'created_at' => $row['created_at'],
            'is_read'    => (bool) $row['is_read'],
        ];
    }, $rows);
    respond(200, ['success' => true, 'data' => $data]);
} catch (Throwable $e) {
    error_log('LIST NOTIFICATIONS ERROR: ' . $e->getMessage());
    respond(500, ['success' => false, 'message' => 'Gagal mengambil notifikasi.']);
}
