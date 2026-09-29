# Python client

Requires Python 3 and curl on PATH. Keep user_agents.json beside proxy_bypass.py.

```sh
python3 proxy_bypass.py -l
python3 proxy_bypass.py -P ai -p 127.0.0.1:8080 -T https://authorized.example/
```

Use -h for all options. Explicitly choose an authorized target: the legacy default is www.google.com.
Requests use HEAD, TLS verification, a 20-second curl timeout, and the selected proxy for HTTP and HTTPS.
Redirects are not followed. Success means the final response is 2xx, not proof of an authorization bypass.
Custom JSON/text libraries are supported with -uf. Control characters in request headers are rejected.
