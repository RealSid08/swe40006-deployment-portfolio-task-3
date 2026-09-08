#!/bin/bash
# Run as root on the initial EC2 or an AMI-derived backend. Never enable shell tracing.
set -euo pipefail
: "${APP_SECRET_ID:?Set APP_SECRET_ID}"
: "${AWS_DEFAULT_REGION:?Set AWS_DEFAULT_REGION}"
db_host=${1:?Usage: configure-db.sh DATABASE_HOST}
umask 077
secret_file=$(mktemp)
trap 'rm -f "$secret_file"' EXIT
aws secretsmanager get-secret-value --secret-id "$APP_SECRET_ID" \
  --query SecretString --output text > "$secret_file"
python3 - "$secret_file" "$db_host" <<'PY'
import json,os,sys,tempfile
from pathlib import Path
secret=json.loads(Path(sys.argv[1]).read_text())
config={'host':sys.argv[2],'database':'wordpress',
        'username':secret['username'],'password':secret['password']}
fd,name=tempfile.mkstemp(prefix='portfolio-db-',dir='/etc')
with os.fdopen(fd,'w') as f: json.dump(config,f)
os.replace(name,'/etc/portfolio-db.json')
PY
chown root:apache /etc/portfolio-db.json
chmod 640 /etc/portfolio-db.json
printf 'Application database configuration written outside the web root.\n'
