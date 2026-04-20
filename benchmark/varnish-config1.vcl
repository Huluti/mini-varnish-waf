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
