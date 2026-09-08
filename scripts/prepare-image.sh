#!/bin/bash
# Run only after migration and file restore have been verified.
# The initial server becomes unavailable until its runtime config is restored.
set -euo pipefail
systemctl stop httpd php-fpm
systemctl disable --now mariadb
rm -f /etc/portfolio-db.json /root/task3-wordpress-admin-password
# Remove the initial database's local files; the verified RDS copy is authoritative.
# Keep this script's purpose explicit so an AMI never ships stale database contents.
rm -rf /var/lib/mysql /var/www/html-before-install
chown -R root:root /opt/task3
chmod -R go-w /opt/task3
echo 'Image prepared: web services stopped, local DB removed, runtime DB credentials removed.'
echo 'Capture an encrypted AMI now. Launch-template user data restores runtime configuration.'
