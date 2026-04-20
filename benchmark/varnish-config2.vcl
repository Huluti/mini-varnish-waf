vcl 4.1;

# Backend definition
backend default {
    .host = "nginx";
    .port = "80";
    .connect_timeout = 5s;
    .first_byte_timeout = 10s;
    .between_bytes_timeout = 5s;
}

sub vcl_recv {
        // --------------------------------------------
    // Mini WAF
    // --------------------------------------------

    // Isolate path
    set req.http.Path = req.url;
    set req.http.Path = regsub(req.http.Path, "\?.*$", "");

    // Path detection
    if (
        // Whitelist
        req.http.Path !~ "^/\.well-known/(assetlinks\.json|apple-app-site-association)$" &&
        (
            // Dot paths
            req.http.Path ~ "^/\." ||

            // Server-side scripts and handlers
            req.http.Path ~ "(?i)\.(php[0-9]?|phtml|phar|phps|inc|py)" ||
            req.http.Path ~ "(?i)\.(aspx|ashx|axd|asmx)" ||

            // Database and dump files
            req.http.Path ~ "(?i)\.(sql|sqlite|db|dump)" ||

            // Configuration files
            req.http.Path ~ "(?i)\.(ini|conf)" ||

            // Logs and debug files
            req.http.Path ~ "(?i)\.(bak|old|backup)" ||

            // Executables and binaries
            req.http.Path ~ "(?i)\.(exe|msi|dll)" ||

            // Archives and compressed files
            req.http.Path ~ "(?i)\.(tar|gz|bz2|xz|7z|rar|zip|tgz|tbz2|lz|zst)"
        )
    ) {
        return (synth(404, "Security-Check-Failed"));
    }

    // --------------------------------------------
    // End of mini WAF
    // --------------------------------------------

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Remove cookies for static content
    if (req.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|svg)$") {
        unset req.http.Cookie;
        return (hash);
    }

    # Don't cache API endpoints
    if (req.url ~ "^/api/") {
        return (pass);
    }

    return (hash);
}

sub vcl_backend_response {
    # Set default TTL
    set beresp.ttl = 10m;

    # Cache static assets longer
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 30d;
    }

    # Shorter TTL for HTML
    if (bereq.url ~ "\.html$") {
        set beresp.ttl = 5m;
    }

    # Don't cache by default if no explicit cache headers
    if (beresp.http.Cache-Control ~ "private|no-cache|no-store") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    return (deliver);
}

sub vcl_deliver {
    # Add cache status header for debugging
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    set resp.http.X-Cache-Hits = obj.hits;
    return (deliver);
}
