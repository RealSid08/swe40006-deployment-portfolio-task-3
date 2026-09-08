<?php
// Credentials stay outside the document root and are populated by the instance role.
$db = json_decode(file_get_contents('/etc/portfolio-db.json'), true, 512, JSON_THROW_ON_ERROR);
$site = json_decode(file_get_contents('/etc/portfolio-url.json'), true, 512, JSON_THROW_ON_ERROR);
define('DB_NAME', $db['database']);
define('DB_USER', $db['username']);
define('DB_PASSWORD', $db['password']);
define('DB_HOST', $db['host']);
if ($db['host'] !== 'localhost') {
    // mysqlnd verifies the server certificate against the system CA trust store.
    define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
}
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
define('WP_HOME', $site['url']);
define('WP_SITEURL', $site['url']);
require '/etc/portfolio-salts.php';
$table_prefix = 'wp_';
define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('DISABLE_WP_CRON', true);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
