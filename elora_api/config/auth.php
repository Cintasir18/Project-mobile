<?php

function requireAdmin(PDO $pdo): array
{
    header('Content-Type: application/json; charset=utf-8');

    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authHeader = '';

    foreach ($headers as $key => $value) {
        if (strtolower($key) === 'authorization') {
            $authHeader = $value;
            break;
        }
    }

    if ($authHeader === '') {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    }

    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $authHeader, $matches)) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Token tidak ditemukan atau tidak valid.'
        ]);
        exit;
    }

    $tokenHash = hash('sha256', $matches[1]);

    try {
        $stmt = $pdo->prepare(
            'SELECT u.id, u.nama, u.email, u.student_id,
                    u.institution, u.role
             FROM api_tokens t
             JOIN users u ON u.id = t.user_id
             WHERE t.token_hash = ?
               AND t.expires_at > NOW()
               AND u.is_active = 1
             LIMIT 1'
        );

        $stmt->execute([$tokenHash]);
        $user = $stmt->fetch();

        if (!$user) {
            http_response_code(401);
            echo json_encode([
                'success' => false,
                'message' => 'Sesi tidak valid atau akun dinonaktifkan.'
            ]);
            exit;
        }

        if (strtolower(trim((string) $user['role'])) !== 'admin') {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Akses hanya tersedia untuk admin.'
            ]);
            exit;
        }

        return $user;

    } catch (PDOException $e) {
        error_log('ELORA ADMIN AUTH ERROR: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Terjadi kesalahan pada server.'
        ]);
        exit;
    }
}

function requireUser(PDO $pdo): array
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if ($auth === '') {
        $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    }

    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $auth, $m)) {
        respond(401, ['success' => false, 'message' => 'Unauthorized.']);
        exit;
    }

    $hash = hash('sha256', $m[1]);
    $stmt = $pdo->prepare(
        'SELECT u.id, u.nama, u.email, u.role FROM api_tokens t
         JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = ? AND t.expires_at > NOW() AND u.is_active = 1 LIMIT 1'
    );
    $stmt->execute([$hash]);
    $user = $stmt->fetch();

    if (!$user) {
        respond(401, ['success' => false, 'message' => 'Sesi tidak valid.']);
        exit;
    }

    return $user;
}
