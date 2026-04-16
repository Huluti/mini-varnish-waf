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

## Contributions

Contributions are welcome.

## License

MIT Licence
