<?php

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (
    preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/192\.168\.\d+\.\d+(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/10\.\d+\.\d+\.\d+(:\d+)?$/', $origin)
    || preg_match('/^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d+\.\d+(:\d+)?$/', $origin)
) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
}
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

function respond(int $s, array $d): void {
    http_response_code($s);
    echo json_encode($d, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method tidak diizinkan.']);
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/auth.php';

$admin = requireAdmin($pdo);

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

$input  = json_decode(file_get_contents('php://input'), true);
$title  = trim($input['title']  ?? '');
$body   = trim($input['body']   ?? '');
$target = $input['target'] ?? 'all';

if ($title === '' || $body === '') {
    respond(422, ['success' => false, 'message' => 'title dan body wajib diisi.']);
}

try {
    if ($target === 'all') {
        $rows = $pdo->query("SELECT fcm_token FROM fcm_tokens")->fetchAll(PDO::FETCH_COLUMN);
    } else {
        $stmt = $pdo->prepare("SELECT fcm_token FROM fcm_tokens WHERE user_id = ? LIMIT 1");
        $stmt->execute([(int) $target]);
        $rows = $stmt->fetchAll(PDO::FETCH_COLUMN);
    }
} catch (Throwable $e) {
    error_log('FCM SEND FETCH ERROR: ' . $e->getMessage());
    respond(500, ['success' => false, 'message' => 'Gagal mengambil token.']);
}

if (empty($rows)) {
    respond(404, ['success' => false, 'message' => 'Tidak ada device terdaftar.']);
}

try {
    $isAll = ($target === 'all');
    $ins   = $pdo->prepare(
        'INSERT INTO notifications (title, body, type, target, target_user_id, created_by)
         VALUES (:title, :body, :type, :target, :target_user_id, :created_by)'
    );
    $ins->execute([
        ':title'          => $title,
        ':body'           => $body,
        ':type'           => 'general',
        ':target'         => $isAll ? 'all' : 'user',
        ':target_user_id' => $isAll ? null : (int) $target,
        ':created_by'     => (int) $admin['id'],
    ]);
} catch (Throwable $e) {
    error_log('NOTIFICATION INSERT ERROR: ' . $e->getMessage());
}

$serviceAccountPath = __DIR__ . '/../config/service-account.json';

if (!file_exists($serviceAccountPath)) {
    respond(500, ['success' => false, 'message' => 'service-account.json tidak ditemukan.']);
}

$sa = json_decode(file_get_contents($serviceAccountPath), true);
if (!$sa || ($sa['type'] ?? '') !== 'service_account') {
    respond(500, ['success' => false, 'message' => 'service-account.json tidak valid.']);
}

$projectId = $sa['project_id'];

function getAccessToken(array $sa): string {
    $now    = time();
    $header = base64_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claim  = base64_encode(json_encode([
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ]));

    $header = rtrim(strtr($header, '+/', '-_'), '=');
    $claim  = rtrim(strtr($claim,  '+/', '-_'), '=');

    $unsignedJwt = "$header.$claim";
    $privateKey  = $sa['private_key'];

    openssl_sign($unsignedJwt, $signature, $privateKey, 'SHA256');
    $sig = rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
    $jwt = "$unsignedJwt.$sig";

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($resp, true);
    return $data['access_token'] ?? '';
}

$accessToken = getAccessToken($sa);
if ($accessToken === '') {
    respond(500, ['success' => false, 'message' => 'Gagal mendapatkan access token FCM.']);
}

$tokens = array_values($rows);
$sent   = 0;
$failed = 0;
$fcmUrl = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

foreach ($tokens as $deviceToken) {
    $payload = json_encode([
        'message' => [
            'token' => $deviceToken,
            'notification' => [
                'title' => $title,
                'body'  => $body,
            ],
            'android' => [
                'notification' => [
                    'channel_id' => 'elora_notifications',
                    'sound'      => 'default',
                ],
                'priority' => 'high',
            ],
            'data' => [
                'title' => $title,
                'body'  => $body,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ],
        ],
    ], JSON_UNESCAPED_UNICODE);

    $ch = curl_init($fcmUrl);
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_HTTPHEADER     => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . $accessToken,
        ],
        CURLOPT_POSTFIELDS => $payload,
    ]);

    $resp     = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200) {
        $sent++;
    } else {
        $failed++;
        error_log("FCM V1 ERROR [$httpCode]: $resp");
    }
}

respond(200, [
    'success' => true,
    'message' => "Notifikasi dikirim. Berhasil: $sent, Gagal: $failed.",
    'sent'    => $sent,
    'failed'  => $failed,
]);
