# Mini Varnish WAF

Lightweight request filter in `vcl_recv` that blocks access to sensitive or heavy file paths.

## Goal

This is **not primarily a security feature**.
The main purpose is **performance optimization**, by avoiding unnecessary backend requests for paths that are almost always invalid or wasteful.

## Better alternatives

If you need a real security layer (beyond simple request filtering), prefer dedicated WAF solutions:

- [Varnish WAF (ModSecurity integration)](https://docs.varnish-software.com/varnish-waf/modsecurity/)
- Cloud WAF services
- Reverse proxy/API gateways with filtering

## What it does

It inspects the URL path and returns `404 Security-Check-Failed` for requests matching:

- Hidden/dot paths (`/.env`, `/.git`, etc.)
- Server-side scripts (`.php`, `.py`, `.aspx`, etc.)
- Databases/dumps (`.sql`, `.db`, `.dump`)
- Config files (`.ini`, `.conf`)
- Backups/logs (`.bak`, `.old`, `.backup`)
- Executables (`.exe`, `.dll`, `.msi`)
- Archives (`.zip`, `.tar`, `.gz`, etc.)

## Exceptions

Allows:
- `/.well-known/assetlinks.json`
- `/.well-known/apple-app-site-association`

## Response

Blocked requests return:
`404 Security-Check-Failed`

## Benchmarking

While the WAF rules seems to incur a performance hit of 1–4% in raw throughput, the reduction in unnecessary backend load makes it a worthwhile trade-off for overall system stability.

| Metric | Config 1 (Without WAF) | Config 2 (With WAF) | Difference |
| :--- | :--- | :--- | :--- |
| **Requests/sec** | 13,498.81 | 13,050.25 | -3.32% |
| **Mean Time (ms)** | 7.408 | 7.663 | +0.255ms |
| **Cache Hit Rate** | 99.99% | 99.99% | 0.00% |

### To run the benchmark

- `cd benchmark`
- `docker compose up -d`
- `chmod +x benchmark.sh`
- `./benchmark.sh`

## Contributions

Contributions are welcome.

## License

MIT Licence
