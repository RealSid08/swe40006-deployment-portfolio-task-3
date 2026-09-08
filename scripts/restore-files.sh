#!/bin/bash
# Restore to a new directory first, compare content, then atomically switch web roots.
set -euo pipefail
umask 077
# shellcheck source=/dev/null
source /opt/task3/environment
key=${1:?Usage: restore-files.sh S3_OBJECT_KEY}
work=$(mktemp -d /var/www/task3-restore.XXXXXX)
trap 'rm -rf "$work"' EXIT
aws s3 cp "s3://$BACKUP_BUCKET/$key" "$work/wordpress.tar.gz" --only-show-errors
expected=$(aws s3api head-object --bucket "$BACKUP_BUCKET" --key "$key" \
  --query Metadata.sha256 --output text)
printf '%s  %s\n' "$expected" "$work/wordpress.tar.gz" | sha256sum -c -
tar -xzf "$work/wordpress.tar.gz" -C "$work"
diff -qr /var/www/html "$work/html"
echo 'Restored file tree matches the original.'
chown -R apache:apache "$work/html"
systemctl stop httpd
mv /var/www/html "$work/original-html"
mv "$work/html" /var/www/html
systemctl restart php-fpm httpd
if ! curl --fail --retry 10 --retry-delay 2 http://127.0.0.1/health.php; then
  systemctl stop httpd
  mv /var/www/html "$work/failed-html"
  mv "$work/original-html" /var/www/html
  systemctl restart php-fpm httpd
  echo 'Restore validation failed; reinstated the original files.' >&2
  exit 1
fi
printf '\nRestored application is serving successfully from the downloaded files.\n'
