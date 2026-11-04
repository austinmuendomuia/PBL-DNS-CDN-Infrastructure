#!/usr/bin/env bash
# ==============================================================================
# Script: verify-dns.sh
# Purpose: End-to-End DNS Tree & Geo-DNS Validation for Debian VMs
# Author: Okwudili Ujubuonu (Dili) - Technical Lead
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

RESOLVER_IP="${1:-10.10.1.10}"
ROOT_IP="${2:-10.10.1.2}"
TLD_IP="${3:-10.10.1.3}"
AUTH_IP="${4:-10.10.1.4}"
GEODNS_IP="${5:-10.10.1.5}"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   PBL DNS TREE & CDN GEO-DNS VERIFICATION SUITE      ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo "Testing against Resolver: $RESOLVER_IP"
echo ""

# Function to run test
run_test() {
    local desc="$1"
    local cmd="$2"
    local expected="$3"

    echo -ne "[TEST] $desc ... "
    result=$(eval "$cmd" 2>/dev/null)

    if echo "$result" | grep -E -q "$expected"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo -e "   Expected match: '$expected'"
        echo -e "   Output was:\n$result"
    fi
}

echo -e "${YELLOW}>>> STEP 1: Verify DNS Tree Hierarchy & Iterative Resolution${NC}"
run_test "Root DNS (.) delegation to .cns" \
    "dig @$ROOT_IP cns. NS +norecurse" \
    "tld-ns\.cns\."

run_test "TLD (.cns) delegation to isp.cns" \
    "dig @$TLD_IP isp.cns. NS +norecurse" \
    "ns1\.isp\.cns\."

run_test "TLD (.cns) delegation to cdn.cns" \
    "dig @$TLD_IP cdn.cns. NS +norecurse" \
    "ns-geo\.cdn\.cns\."

run_test "Recursive Resolver traverses tree for mail1.isp.cns" \
    "dig @$RESOLVER_IP mail1.isp.cns +short" \
    "10\.10\.20\.11"

echo ""
echo -e "${YELLOW}>>> STEP 2: Verify Compulsory Email Authentication (Roy's Workstream)${NC}"
run_test "MX Records for isp.cns" \
    "dig @$RESOLVER_IP isp.cns MX +short" \
    "10 mail1\.isp\.cns\."

run_test "Reverse DNS (PTR) for mail1 (10.10.20.11)" \
    "dig @$RESOLVER_IP -x 10.10.20.11 +short" \
    "mail1\.isp\.cns\."

run_test "Reverse DNS (PTR) for mail2 (10.10.20.12)" \
    "dig @$RESOLVER_IP -x 10.10.20.12 +short" \
    "mail2\.isp\.cns\."

run_test "SPF Record (TXT) for email spoof prevention" \
    "dig @$RESOLVER_IP isp.cns TXT +short" \
    "v=spf1"

run_test "DKIM Public Key Record (TXT)" \
    "dig @$RESOLVER_IP default._domainkey.isp.cns TXT +short" \
    "v=DKIM1"

echo ""
echo -e "${YELLOW}>>> STEP 3: Verify Compulsory ISP Network Services (Austin & Joe)${NC}"
run_test "RADIUS IAM endpoint resolution" \
    "dig @$RESOLVER_IP radius.isp.cns +short" \
    "10\.10\.30\.10"

run_test "Billing Portal endpoint resolution" \
    "dig @$RESOLVER_IP billing.isp.cns +short" \
    "10\.10\.30\.20"

run_test "xPON OLT Controller resolution" \
    "dig @$RESOLVER_IP olt.isp.cns +short" \
    "10\.10\.40\.1"

echo ""
echo -e "${YELLOW}>>> STEP 4: Verify CDN Origin & DB Clusters (Joy Ndira)${NC}"
run_test "Origin Web Load Balancer (HAProxy VIP)" \
    "dig @$RESOLVER_IP origin.isp.cns +short" \
    "10\.10\.50\.100"

run_test "MySQL Primary Master" \
    "dig @$RESOLVER_IP db-primary.isp.cns +short" \
    "10\.10\.50\.11"

echo ""
echo -e "${YELLOW}>>> STEP 5: Verify Geo-DNS Steering by Client Subnet (CDN Elective)${NC}"
run_test "Geo-DNS View: Region West (Client 10.10.10.50 -> Edge 1)" \
    "dig @$GEODNS_IP cdn.cns +subnet=10.10.10.50/24 +short" \
    "10\.10\.60\.10"

run_test "Geo-DNS View: Region East (Client 10.20.10.50 -> Edge 2)" \
    "dig @$GEODNS_IP cdn.cns +subnet=10.20.10.50/24 +short" \
    "10\.20\.60\.10"

run_test "Geo-DNS View: Default / Global Anycast (Client 172.16.1.5 -> Anycast VIP)" \
    "dig @$GEODNS_IP cdn.cns +subnet=172.16.1.5/24 +short" \
    "10\.99\.99\.99"

echo ""
echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}   VERIFICATION TESTS COMPLETE                        ${NC}"
echo -e "${BLUE}======================================================${NC}"
