
<?php
header('Content-Type: application/json');

echo json_encode([
    'success' => true,
    'message' => 'ELORA API berhasil berjalan!',
    'php_version' => PHP_VERSION
]);
