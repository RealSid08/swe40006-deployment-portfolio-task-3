#!/bin/bash
set -euo pipefail
site_url=${1:?Usage: configure-url.sh PUBLIC_URL}
python3 - "$site_url" <<'PY'
import json,sys
from pathlib import Path
from urllib.parse import urlparse
url=sys.argv[1].rstrip('/')
parsed=urlparse(url)
if parsed.scheme not in ('http','https') or not parsed.hostname:
    raise SystemExit('A valid HTTP(S) URL is required')
Path('/etc/portfolio-url.json').write_text(json.dumps({'url':url}))
PY
chown root:apache /etc/portfolio-url.json
chmod 640 /etc/portfolio-url.json
