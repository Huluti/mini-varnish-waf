#!/bin/bash

####################################################
# Mini Varnish WAF - Battle Test Script
# Test the WAF rules against a live Varnish instance
####################################################

TARGET="https://website-to-test.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
UNEXPECTED=0

function test_payload() {
    local payload="$1"
    local expected="$2"  # "block" or "pass"
    local description="$3"

    local url="${TARGET}${payload}"
    local response_line=$(curl -s -I "$url" | head -n 1)
    local response_code=$(echo "$response_line" | awk '{print $2}')
    local response_msg=$(echo "$response_line" | cut -d' ' -f3- | tr -d '\r')

    local status="❓"
    local color="$YELLOW"

    if [ "$expected" = "block" ]; then
        if [ "$response_code" = "404" ] && [ "$response_msg" = "Security-Check-Failed" ]; then
            status="✅ BLOCKED"
            color="$GREEN"
            ((PASSED++))
        else
            status="❌ PASSED (should block!)"
            color="$RED"
            ((FAILED++))
        fi
    else  # pass
        if [ "$response_msg" != "Security-Check-Failed" ]; then
            status="✅ PASSED"
            color="$GREEN"
            ((PASSED++))
        else
            status="❌ BLOCKED (should pass!)"
            color="$RED"
            ((FAILED++))
        fi
    fi

    printf "${color}%-50s${NC} [HTTP %s] %s\n" \
        "$description" \
        "$response_code" \
        "$status"
}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Varnish Mini WAF - Battle Tests${NC}"
echo -e "${BLUE}Target: $TARGET${NC}"
echo -e "${BLUE}================================${NC}\n"

# CATEGORY 1: Should BLOCK - Dot files

echo -e "${YELLOW}[CATEGORY 1] Dot Files (Should BLOCK)${NC}"
echo "────────────────────────────────────────"

test_payload "/.htaccess" "block" "/.htaccess - Classic bot target"
test_payload "/.env" "block" "/.env - Environment config"
test_payload "/.git/config" "block" "/.git/config - Git enumeration"
test_payload "/.gitignore" "block" "/.gitignore - Git metadata"
test_payload "/.well-known/security.txt" "block" ".well-known/security.txt - NOT whitelisted"
test_payload "/.aws/credentials" "block" "/.aws/credentials - AWS config"
test_payload "/.ssh/id_rsa" "block" "/.ssh/id_rsa - SSH keys"
test_payload "/.env.local" "block" "/.env.local - Local env file"
test_payload "/.config/database.yml" "block" "/.config/database.yml - Rails config"

echo ""

# CATEGORY 2: Should BLOCK - PHP execution

echo -e "${YELLOW}[CATEGORY 2] PHP Files (Should BLOCK)${NC}"
echo "────────────────────────────────────────"

test_payload "/admin.php" "block" "/admin.php - Direct PHP file"
test_payload "/shell.php" "block" "/shell.php - Webshell"
test_payload "/test.php?cmd=id" "block" "/test.php?cmd=id - PHP with query"
test_payload "/test.php?foo=bar" "block" "/test.php?foo=bar - PHP with params"
test_payload "/upload.PHP" "block" "/upload.PHP - Uppercase PHP"
test_payload "/config.PhP" "block" "/config.PhP - Mixed case PHP"

echo ""

# CATEGORY 3: WEAKNESS TEST - Alternative PHP extensions

echo -e "${YELLOW}[CATEGORY 3] Alternative PHP Extensions (WEAKNESS TEST)${NC}"
echo "────────────────────────────────────────"

test_payload "/shell.phtml" "block" "/shell.phtml - PHTML extension ⚠️"
test_payload "/shell.php3" "block" "/shell.php3 - PHP3 extension ⚠️"
test_payload "/shell.php4" "block" "/shell.php4 - PHP4 extension ⚠️"
test_payload "/shell.php5" "block" "/shell.php5 - PHP5 extension ⚠️"
test_payload "/shell.php7" "block" "/shell.php7 - PHP7 extension ⚠️"
test_payload "/shell.inc" "block" "/shell.inc - Include file ⚠️"
test_payload "/shell.phar" "block" "/shell.phar - PHAR archive ⚠️"
test_payload "/shell.phps" "block" "/shell.phps - PHP source ⚠️"

echo ""

# CATEGORY 4: WEAKNESS TEST - Path traversal variants

echo -e "${YELLOW}[CATEGORY 4] Path Traversal Variants (WEAKNESS TEST)${NC}"
echo "────────────────────────────────────────"

test_payload "/shell.php/" "block" "/shell.php/ - PHP with trailing slash ⚠️"
test_payload "/shell.php/image" "block" "/shell.php/image - PHP path traversal ⚠️"
test_payload "/shell.php/foo.jpg" "block" "/shell.php/foo.jpg - PHP path bypass ⚠️"
test_payload "/.php" "block" "/.php - Just extension"

echo ""

# CATEGORY 5: Should PASS - Valid URLs

echo -e "${YELLOW}[CATEGORY 5] Valid URLs (Should PASS)${NC}"
echo "────────────────────────────────────────"

test_payload "/abc123" "pass" "/abc123 - Valid alphanumeric slug"
test_payload "/short" "pass" "/short - Valid word slug"
test_payload "/my-link" "pass" "/my-link - Valid slug with dash"
test_payload "/my_link" "pass" "/my_link - Valid slug with underscore"
test_payload "/AbC123" "pass" "/AbC123 - Mixed case slug"
test_payload "/link123456789" "pass" "/link123456789 - Long slug"
test_payload "/a" "pass" "/a - Single character slug"

echo ""

# CATEGORY 6: Should PASS - Valid static assets

echo -e "${YELLOW}[CATEGORY 6] Valid Static Files (Should PASS)${NC}"
echo "────────────────────────────────────────"

test_payload "/favicon.ico" "pass" "/favicon.ico - Browser favicon"
test_payload "/robots.txt" "pass" "/robots.txt - SEO crawler file"
test_payload "/sitemap.xml" "pass" "/sitemap.xml - SEO sitemap"
test_payload "/assets/app.js" "pass" "/assets/app.js - JavaScript asset"
test_payload "/assets/style.css" "pass" "/assets/style.css - CSS asset"
test_payload "/images/logo.png" "pass" "/images/logo.png - PNG image"
test_payload "/images/banner.jpg" "pass" "/images/banner.jpg - JPG image"
test_payload "/fonts/inter.woff2" "pass" "/fonts/inter.woff2 - Web font"
test_payload "/backup/report.pdf" "pass" "/backup/report.pdf - Report"

echo ""

# CATEGORY 7: Should PASS - Whitelisted .well-known
echo -e "${YELLOW}[CATEGORY 7] Whitelisted .well-known (Should PASS)${NC}"
echo "────────────────────────────────────────"

test_payload "/.well-known/assetlinks.json" "pass" "/.well-known/assetlinks.json - WHITELISTED"
test_payload "/.well-known/apple-app-site-association" "pass" "/.well-known/apple-app-site-association - WHITELISTED"

echo ""

# CATEGORY 8: Edge Cases
echo -e "${YELLOW}[CATEGORY 8] Edge Cases${NC}"
echo "────────────────────────────────────────"

test_payload "/?foo=.env" "pass" "/?foo=.env - Dot in query param (safe)"
test_payload "/redirect?url=.env" "pass" "/redirect?url=.env - Dot in URL param (safe)"
test_payload "/search?q=.php" "pass" "/search?q=.php - PHP in search param (safe)"

echo ""

# CATEGORY 9: Sensitive files (Should BLOCK)

echo -e "${YELLOW}[CATEGORY 9] Sensitive File Exposure (Should BLOCK)${NC}"
echo "────────────────────────────────────────"

test_payload "/database.sql" "block" "/database.sql - SQL dump"
test_payload "/backup.sql" "block" "/backup.sql - Database backup"
test_payload "/dump.sql" "block" "/dump.sql - SQL export"
test_payload "/data.sqlite" "block" "/data.sqlite - SQLite database"
test_payload "/db.sqlite" "block" "/db.sqlite - SQLite DB file"
test_payload "/app.db" "block" "/app.db - Generic database file"
test_payload "/config.bak" "block" "/config.bak - Backup config"
test_payload "/index.php.bak" "block" "/index.php.bak - PHP backup leak"
test_payload "/settings.old" "block" "/settings.old - Old config file"
test_payload "/site.backup" "block" "/site.backup - Backup archive"
test_payload "/prod.dump" "block" "/prod.dump - Database dump"

echo ""

# Results

TOTAL=$((PASSED + FAILED))

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}RESULTS${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Errors:${NC} $ERRORS"
echo -e "${BLUE}Total:${NC}  $TOTAL"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
