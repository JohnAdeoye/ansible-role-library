# nginx

NGINX with templated virtual hosts, TLS, security headers, rate limiting and log rotation.
RHEL/Rocky 9 and Ubuntu 22.04.

## What it does that a `package: nginx` task does not

- **Renders vhosts from data.** One `nginx_sites` list produces every server block.
- **Reconciles `sites-enabled`.** Removing a site from `nginx_sites`, or setting
  `enabled: false`, actually takes it out of service. Most nginx roles only ever add
  symlinks, so a deleted vhost keeps serving traffic until somebody notices.
- **Validates before reloading.** `nginx.conf` is written with `validate: nginx -t -c %s`,
  so a broken template cannot reach disk, and the role runs a final `nginx -t` before
  touching the service.
- **Puts the WebSocket `map` in `http` context.** It is only legal there, which is why
  proxy settings are split between a snippet and the main config.

## Usage

```yaml
- role: nginx
  vars:
    nginx_hsts_enabled: true
    nginx_sites:
      - name: app
        server_name: app.lab.internal
        listen: 443
        tls:
          cert: /etc/pki/tls/certs/app.crt
          key: /etc/pki/tls/private/app.key
        locations:
          - path: /
            proxy_pass: http://127.0.0.1:8080
            rate_limit: general
            burst: 20
          - path: /login
            proxy_pass: http://127.0.0.1:8080
            rate_limit: login          # 5r/m — credential stuffing costs real time
          - path: /ws
            proxy_pass: http://127.0.0.1:8080
            websocket: true
          - path: /metrics
            proxy_pass: http://127.0.0.1:9100
            allow: ["10.0.0.0/8"]      # everything else gets 403
```

With `tls` set, a `:80` server block that 301s to HTTPS is emitted automatically
(`redirect_http: false` to suppress it). `/.well-known/acme-challenge/` is left on
plain HTTP so certificate renewal keeps working.

## Defaults worth knowing

| Variable | Default | Notes |
|---|---|---|
| `nginx_ssl_protocols` | `TLSv1.2 TLSv1.3` | Drop 1.2 once nothing on the network needs it |
| `nginx_hsts_enabled` | `false` | Effectively irreversible for `max-age` once sent |
| `nginx_server_tokens` | `off` | No version in headers or error pages |
| `nginx_remove_default_site` | `true` | Removes the distro welcome page |
| `nginx_status_enabled` | `true` | `stub_status` on `127.0.0.1:8080` for the Prometheus exporter |
| `nginx_rate_limit_zones` | `general` 30r/s, `login` 5r/m | Referenced by name from a location |

Rate-limited requests return **429**, not nginx's default 503 — it is the correct
status and clients back off on it.

The full schema for `nginx_sites` is typed in
[`meta/argument_specs.yml`](meta/argument_specs.yml).

## Testing

```bash
molecule test
```

Covers a static site, a TLS site with a self-signed cert, rate limiting, WebSocket
upgrade, IP-restricted locations, and a site with `enabled: false` — asserting that the
disabled one is *not* linked into `sites-enabled`. The final check fetches a page over
HTTP and asserts the security headers are on the live response, not just in the file.
