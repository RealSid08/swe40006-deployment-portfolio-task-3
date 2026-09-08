#!/bin/bash
# Run on the initial EC2 instance, after capturing the local database evidence.
set -euo pipefail
umask 077
db_host=${1:?Usage: migrate-database.sh RDS_ENDPOINT RDS_MASTER_SECRET_ARN}
master_secret=${2:?Supply the RDS-managed master secret ARN}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source /opt/task3/environment
curl -fsSL --retry 3 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  -o /etc/pki/ca-trust/source/anchors/task3-rds.pem
chmod 644 /etc/pki/ca-trust/source/anchors/task3-rds.pem
update-ca-trust
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if ! python3 -c 'import json; assert json.load(open("/etc/portfolio-db.json"))["host"] == "localhost"'; then
  echo 'The application must still use its local database for this migration.' >&2
  exit 1
fi
wp --allow-root --path=/var/www/html post list --post_type=post --post_status=publish \
  --fields=ID,post_title,post_content,post_status --orderby=ID --order=ASC --format=json > "$work/before.json"
systemctl stop httpd
restart_web() { systemctl start httpd; rm -rf "$work"; }
trap restart_web EXIT
mariadb-dump --single-transaction --skip-lock-tables wordpress > "$work/wordpress.sql"
aws secretsmanager get-secret-value --secret-id "$master_secret" \
  --query SecretString --output text > "$work/master.json"
python3 - "$work/master.json" "$work/client.cnf" "$db_host" <<'PY'
import json,sys
from pathlib import Path
c=json.loads(Path(sys.argv[1]).read_text())
def quote(s):
    return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
Path(sys.argv[2]).write_text('[client]\nssl-ca=/etc/pki/ca-trust/source/anchors/task3-rds.pem\nssl-verify-server-cert\n'+''.join(
    f'{k}={quote(v)}\n' for k,v in {'host':sys.argv[3],
    'user':c['username'],'password':c['password']}.items()))
PY
mariadb --defaults-extra-file="$work/client.cnf" wordpress < "$work/wordpress.sql"
python3 - <<'PY' | mariadb --defaults-extra-file="$work/client.cnf"
import json,re
c=json.load(open('/etc/portfolio-db.json'))
assert re.fullmatch(r'[A-Za-z0-9]+',c['password'])
print("CREATE USER IF NOT EXISTS 'wpapp'@'%%' IDENTIFIED BY '%s';" % c['password'])
print("GRANT ALL PRIVILEGES ON wordpress.* TO 'wpapp'@'%';")
PY
cp /etc/portfolio-db.json "$work/original-db.json"
"$script_dir/configure-db.sh" "$db_host"
if ! wp --allow-root --path=/var/www/html post list --post_type=post --post_status=publish \
  --fields=ID,post_title,post_content,post_status --orderby=ID --order=ASC --format=json > "$work/after.json" \
  || ! cmp --silent "$work/before.json" "$work/after.json"; then
  cp "$work/original-db.json" /etc/portfolio-db.json
  chown root:apache /etc/portfolio-db.json
  chmod 640 /etc/portfolio-db.json
  echo 'Content verification failed; restored the local database configuration.' >&2
  exit 1
fi
echo 'Existing database exported from EC2 and imported into RDS.'
echo 'Published content before and after migration:'
sha256sum "$work/before.json" "$work/after.json"
echo 'Content comparison: identical'
systemctl disable --now mariadb
systemctl start httpd
curl --fail --retry 10 --retry-delay 2 http://127.0.0.1/health.php
printf '\nLocal MariaDB stopped; application health passed using RDS.\n'
