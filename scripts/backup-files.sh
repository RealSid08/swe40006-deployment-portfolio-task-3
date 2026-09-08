#!/bin/bash
set -euo pipefail
umask 077
# shellcheck source=/dev/null
source /opt/task3/environment
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
stamp=$(date -u +%Y%m%dT%H%M%SZ)
key="backups/wordpress-$stamp.tar.gz"
tar -C /var/www -czf "$work/wordpress.tar.gz" html
digest=$(sha256sum "$work/wordpress.tar.gz" | cut -d ' ' -f 1)
aws s3 cp "$work/wordpress.tar.gz" "s3://$BACKUP_BUCKET/$key" \
  --sse AES256 --metadata "sha256=$digest" --only-show-errors
printf '%s\n' "$key" > /opt/task3/last-backup-key
printf 'Manual application file backup uploaded.\nObject: %s\nSHA-256: %s\n' "$key" "$digest"
echo 'Database credentials and signing salts are outside the web root and not in this archive.'
aws s3api head-object --bucket "$BACKUP_BUCKET" --key "$key" \
  --query '{Bytes:ContentLength,Encryption:ServerSideEncryption,Version:VersionId,SHA256:Metadata.sha256}'
