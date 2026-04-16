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
}
