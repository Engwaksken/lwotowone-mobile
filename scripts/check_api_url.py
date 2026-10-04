import os
from urllib.parse import urlparse
address = os.environ.get("API_BASE_URL", "")
uri = urlparse(address)
host = (uri.hostname or "").lower()
if (uri.scheme != "https" or not host or not uri.path.endswith("/api")
    or uri.query or uri.fragment or uri.username or uri.password
    or host == "example.com" or host.endswith(".example.com") or "your-domain" in host):
    raise SystemExit("Use your actual HTTPS API address ending in /api.")
try:
    if uri.port is not None and not 1 <= uri.port <= 65535:
        raise ValueError("Port out of range")
except ValueError:
    raise SystemExit("Use a valid API port.")
print("API build configuration validated.")
