#!/bin/bash
set -euo pipefail
umask 077
site_url=${1:?Usage: install-wordpress.sh PUBLIC_URL}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source /opt/task3/environment
if [[ -f /var/www/html/wp-config.php ]]; then
  echo 'WordPress is already configured. Refusing to overwrite the installation.' >&2
  exit 1
fi
systemctl is-active --quiet mariadb
systemctl is-active --quiet httpd
curl -fsSL --retry 3 https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar -o /usr/local/bin/wp
printf '%s  %s\n' ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c /usr/local/bin/wp | sha256sum -c -
chmod 755 /usr/local/bin/wp
"$script_dir/configure-db.sh" localhost
"$script_dir/configure-url.sh" "$site_url"
python3 - <<'PY' | mariadb
import json,re
c=json.load(open('/etc/portfolio-db.json'))
assert re.fullmatch(r'[A-Za-z0-9]+',c['password'])
print("CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
print("CREATE USER IF NOT EXISTS 'wpapp'@'localhost' IDENTIFIED BY '%s';" % c['password'])
print("GRANT ALL PRIVILEGES ON wordpress.* TO 'wpapp'@'localhost';")
PY
wp --allow-root --path=/var/www/html core download --version=7.1
wp --allow-root --path=/var/www/html core verify-checksums --version=7.1
install -m 644 "$script_dir/../wordpress/wp-config.php" /var/www/html/wp-config.php
python3 - <<'PY'
import secrets
from pathlib import Path
keys=['AUTH_KEY','SECURE_AUTH_KEY','LOGGED_IN_KEY','NONCE_KEY',
      'AUTH_SALT','SECURE_AUTH_SALT','LOGGED_IN_SALT','NONCE_SALT']
Path('/etc/portfolio-salts.php').write_text('<?php\n'+''.join(
    "define('%s', '%s');\n" % (k,secrets.token_hex(32)) for k in keys))
PY
chown root:apache /etc/portfolio-salts.php
chmod 640 /etc/portfolio-salts.php
mkdir -p /var/www/html/wp-content/mu-plugins /var/www/html/wp-content/themes/portfolio
cp "$script_dir/../wordpress/mu-plugins/"*.php /var/www/html/wp-content/mu-plugins/
cp "$script_dir/../wordpress/themes/portfolio/"* /var/www/html/wp-content/themes/portfolio/
cp "$script_dir/../wordpress/health.php" /var/www/html/health.php
chown -R apache:apache /var/www/html
find /var/www/html -type d -exec chmod 755 {} +
find /var/www/html -type f -exec chmod 644 {} +
python3 - <<'PY'
import secrets,subprocess
from pathlib import Path
password=secrets.token_urlsafe(36)
Path('/root/task3-wordpress-admin-password').write_text(password)
subprocess.run(['wp','--allow-root','--path=/var/www/html','core','install',
 '--url='+__import__('json').load(open('/etc/portfolio-url.json'))['url'],
 '--title=Cloud deployment journal','--admin_user=portfolio-admin',
 '--admin_password='+password,'--admin_email=admin@example.invalid','--skip-email'],check=True)
PY
wp --allow-root --path=/var/www/html theme activate portfolio
wp --allow-root --path=/var/www/html post delete 1 2 --force
wp --allow-root --path=/var/www/html option update blogdescription 'WordPress on AWS | SWE40006 Deployment Portfolio Task 3'
wp --allow-root --path=/var/www/html option update default_comment_status closed
wp --allow-root --path=/var/www/html post create --post_type=post --post_status=publish \
  --post_title='A small application, a complete deployment' \
  --post_content='This WordPress journal is the application used for my AWS deployment portfolio. Its pages are rendered by Apache and PHP, while its posts and settings are stored in MariaDB. I created this post before moving the database so that I could verify the same content after migration.'
wp --allow-root --path=/var/www/html post create --post_type=post --post_status=publish \
  --post_title='Separating the application from its data' \
  --post_content='The deployment starts with WordPress and MariaDB on one EC2 server. The next stage exports that existing database to Amazon RDS. The application keeps its content while the database host changes. File backups and restore checks are a separate part of the workflow.'
wp --allow-root --path=/var/www/html post create --post_type=post --post_status=publish \
  --post_title='Making the web tier replaceable' \
  --post_content='An Application Load Balancer can send requests to identical web instances in two Availability Zones. Each instance uses the same database. The deployment status panel identifies the responding node, making it possible to observe requests being served by different instances.'
systemctl restart php-fpm httpd
curl --fail --retry 10 --retry-delay 2 http://127.0.0.1/health.php
printf '\nWordPress installed and health check passed.\n'
