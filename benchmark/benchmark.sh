#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VARNISH1_URL="http://localhost:6081"
VARNISH2_URL="http://localhost:6083"
NUM_REQUESTS=10000
NUM_CONCURRENT=100

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Varnish Cache Benchmark Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if both Varnish instances are running
echo -e "${YELLOW}Checking Varnish instances...${NC}"
if ! curl -s "$VARNISH1_URL" > /dev/null; then
    echo -e "${RED}✗ Varnish Config 1 is not responding at $VARNISH1_URL${NC}"
    exit 1
fi

if ! curl -s "$VARNISH2_URL" > /dev/null; then
    echo -e "${RED}✗ Varnish Config 2 is not responding at $VARNISH2_URL${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Both Varnish instances are running${NC}"
echo ""

# Function to parse and display results
display_results() {
    local config_name=$1
    local output=$2

    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ ${config_name}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"

    # Extract metrics
    local rps=$(echo "$output" | grep "Requests per second" | awk '{print $4}')
    local mean_time=$(echo "$output" | grep "Time per request" | head -1 | awk '{print $4}')
    local failed=$(echo "$output" | grep "Failed requests" | awk '{print $3}')
    local complete=$(echo "$output" | grep "Complete requests" | awk '{print $3}')
    local transfer=$(echo "$output" | grep "Transfer rate" | awk '{print $3}')

    echo -e "${GREEN}Requests per second:${NC}     ${YELLOW}${rps}${NC}"
    echo -e "${GREEN}Mean response time:${NC}      ${YELLOW}${mean_time} ms${NC}"
    echo -e "${GREEN}Complete requests:${NC}       ${YELLOW}${complete}${NC}"
    echo -e "${GREEN}Failed requests:${NC}         ${RED}${failed}${NC}"
    echo -e "${GREEN}Transfer rate:${NC}           ${YELLOW}${transfer} Kbytes/sec${NC}"
    echo ""
}

# Run benchmarks
echo -e "${BLUE}Starting benchmarks...${NC}"
echo ""

# Config 1
echo -e "${YELLOW}→ Running Config 1 (Without WAF)...${NC}"
RESULT1=$(ab -n $NUM_REQUESTS -c $NUM_CONCURRENT "$VARNISH1_URL/" 2>&1)
display_results "Config 1: Without WAF Varnish" "$RESULT1"

sleep 5

# Config 2
echo -e "${YELLOW}→ Running Config 2 (With WAF)...${NC}"
RESULT2=$(ab -n $NUM_REQUESTS -c $NUM_CONCURRENT "$VARNISH2_URL/" 2>&1)
display_results "Config 2: With WAF" "$RESULT2"

# Cache Statistics
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Cache Statistics${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}Varnish Config 1 (Without WAF):${NC}"
# Use docker exec to run varnishstat inside the container
STATS1=$(docker exec varnish-config1 varnishstat -1 -f MAIN.cache_hit -f MAIN.cache_miss -f MAIN.n_object 2>&1)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Stats not available (Container not found)${NC}"
else
    echo -e "${YELLOW}$STATS1${NC}"
fi
echo ""

echo -e "${CYAN}Varnish Config 2 (With WAF):${NC}"
STATS2=$(docker exec varnish-config2 varnishstat -1 -f MAIN.cache_hit -f MAIN.cache_miss -f MAIN.n_object 2>&1)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Stats not available (Container not found)${NC}"
else
    echo -e "${YELLOW}$STATS2${NC}"
fi
echo ""

# Comparison Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Performance Comparison${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

RPS1=$(echo "$RESULT1" | grep "Requests per second" | awk '{print $4}')
RPS2=$(echo "$RESULT2" | grep "Requests per second" | awk '{print $4}')
TIME1=$(echo "$RESULT1" | grep "Time per request" | head -1 | awk '{print $4}')
TIME2=$(echo "$RESULT2" | grep "Time per request" | head -1 | awk '{print $4}')

echo -e "${CYAN}Summary Table:${NC}"
echo ""
printf "%-35s %-20s %-20s\n" "Metric" "Config 1 (Without WAF)" "Config 2 (With WAF)"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
printf "%-35s %-20s %-20s\n" "Requests/sec" "$RPS1" "$RPS2"
printf "%-35s %-20s %-20s\n" "Mean time (ms)" "$TIME1" "$TIME2"

echo ""

# Calculate improvement
if (( $(echo "$RPS1 > 0" | bc -l) )); then
    IMPROVEMENT=$(echo "scale=2; (($RPS2 - $RPS1) / $RPS1) * 100" | bc 2>/dev/null || echo "N/A")
    if [ "$IMPROVEMENT" != "N/A" ]; then
        if (( $(echo "$IMPROVEMENT > 0" | bc -l) )); then
            echo -e "${GREEN}✓ Config 2 is ${IMPROVEMENT}% faster${NC}"
        elif (( $(echo "$IMPROVEMENT < 0" | bc -l) )); then
            IMPROVEMENT=$(echo "$IMPROVEMENT" | sed 's/-//g')
            echo -e "${YELLOW}Config 1 is ${IMPROVEMENT}% faster${NC}"
        else
            echo -e "${CYAN}Both configs have similar performance${NC}"
        fi
    fi
fi
echo ""

echo -e "${GREEN}✓ Benchmark complete!${NC}"
