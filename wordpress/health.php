<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
try {
    $config = json_decode(file_get_contents('/etc/portfolio-db.json'), true, 512, JSON_THROW_ON_ERROR);
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    $db = mysqli_init();
    $db->options(MYSQLI_OPT_CONNECT_TIMEOUT, 3);
    $remote = $config['host'] !== 'localhost';
    if ($remote) {
        $db->ssl_set(null, null, '/etc/pki/ca-trust/source/anchors/task3-rds.pem', null, null);
        $db->options(MYSQLI_OPT_SSL_VERIFY_SERVER_CERT, true);
    }
    $db->real_connect($config['host'], $config['username'], $config['password'], $config['database'], 3306, null, $remote ? MYSQLI_CLIENT_SSL : 0);
    $cipher = $db->query("SHOW SESSION STATUS LIKE 'Ssl_cipher'")->fetch_assoc()['Value'];
    $result = $db->query("SELECT COUNT(*) AS total FROM wp_posts WHERE post_type='post' AND post_status='publish'")->fetch_assoc();
    echo json_encode([
        'status' => 'healthy',
        'application' => 'WordPress deployment portfolio',
        'database' => $config['host'] === 'localhost' ? 'Local MariaDB on EC2' : 'Amazon RDS MariaDB',
        'published_posts' => (int) $result['total'],
        'database_tls' => $cipher ?: 'local socket',
        'node' => substr(hash('sha256', gethostname()), 0, 8),
        'php' => PHP_VERSION,
        'checked_at' => gmdate('c'),
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
} catch (Throwable $error) {
    error_log('Portfolio health check failed: ' . get_class($error));
    http_response_code(503);
    echo json_encode(['status' => 'unhealthy', 'checked_at' => gmdate('c')]);
}
