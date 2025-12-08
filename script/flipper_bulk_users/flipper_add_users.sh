#!/bin/bash

# Script to add multiple users to a Flipper feature toggle
# Usage: ./flipper_add_users.sh -r <curl_file> -e <email1,email2,...>
# Or:    ./flipper_add_users.sh -r <curl_file> -i <emails_file>

set -e

# Default values
BASE_URL="https://api.va.gov"
OPERATION="enable"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Add users to a Flipper feature toggle"
    echo ""
    echo "Required Options (choose one method):"
    echo ""
    echo "  Method 1 - From curl file (recommended):"
    echo "    -r, --curl-file     Path to file containing curl command copied from browser"
    echo ""
    echo "  Method 2 - Manual parameters:"
    echo "    -f, --feature       Feature toggle name (e.g., mhv_accelerated_delivery_allergies_enabled)"
    echo "    -k, --cookies       Full cookie string from browser (copy from -b flag in curl)"
    echo "    -c, --csrf          CSRF/authenticity token (from form data 'authenticity_token')"
    echo ""
    echo "One of these is required:"
    echo "  -e, --emails        Comma-separated list of email addresses"
    echo "  -i, --input-file    File containing email addresses (one per line)"
    echo ""
    echo "Optional:"
    echo "  -u, --base-url      Base URL (default: https://api.va.gov)"
    echo "  -o, --operation     Operation: enable or disable (default: enable)"
    echo "  -d, --dry-run       Show what would be done without making requests"
    echo "  -v, --verbose       Show extracted values from curl file"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  # From curl file (easiest - just paste curl from browser into a file)"
    echo "  $0 -r curl_command.txt -e 'user@va.gov'"
    echo "  $0 -r curl_command.txt -i emails.txt"
    echo ""
    echo "  # Manual parameters"
    echo "  $0 -f mhv_accelerated_delivery_allergies_enabled -k 'cookies...' -c 'csrf_token' -e 'user@va.gov'"
    echo ""
    echo "How to create curl file:"
    echo "  1. Log into the Flipper UI at ${BASE_URL}/flipper"
    echo "  2. Open browser DevTools (F12) -> Network tab"
    echo "  3. Manually add one user via the UI"
    echo "  4. Right-click the POST request -> Copy as cURL"
    echo "  5. Paste into a text file (e.g., curl_command.txt)"
    echo "  6. Run: $0 -r curl_command.txt -e 'email1@va.gov,email2@va.gov'"
    exit 1
}

# Function to extract values from curl command file
parse_curl_file() {
    local curl_file="$1"
    
    if [[ ! -f "$curl_file" ]]; then
        echo -e "${RED}Error: Curl file not found: $curl_file${NC}"
        exit 1
    fi
    
    # Read the entire file content
    local curl_content
    curl_content=$(cat "$curl_file")
    
    # Extract feature name from URL
    # Pattern: /flipper/features/<feature_name>/actors
    if [[ -z "$FEATURE" ]]; then
        FEATURE=$(echo "$curl_content" | grep -oE "flipper/features/[^/]+/actors" | head -1 | sed 's|flipper/features/||' | sed 's|/actors||')
        if [[ -z "$FEATURE" ]]; then
            echo -e "${RED}Error: Could not extract feature name from curl file${NC}"
            echo "Expected URL pattern: /flipper/features/<feature_name>/actors"
            exit 1
        fi
    fi
    
    # Extract cookies from -b or --cookie flag
    # Handle both single-line and multi-line curl commands
    if [[ -z "$COOKIES" ]]; then
        # First, normalize the curl command by removing line continuations
        local normalized_curl
        normalized_curl=$(echo "$curl_content" | tr -d '\n' | sed 's/\\//g')
        
        # Try to extract cookies - handle both -b 'value' and -b "value" formats
        COOKIES=$(echo "$normalized_curl" | grep -oE "\-b '[^']+'" | head -1 | sed "s/-b '//" | sed "s/'$//")
        
        if [[ -z "$COOKIES" ]]; then
            # Try double quotes
            COOKIES=$(echo "$normalized_curl" | grep -oE '\-b "[^"]+"' | head -1 | sed 's/-b "//' | sed 's/"$//')
        fi
        
        if [[ -z "$COOKIES" ]]; then
            echo -e "${RED}Error: Could not extract cookies from curl file${NC}"
            echo "Expected: -b 'cookie_string' or -b \"cookie_string\""
            exit 1
        fi
    fi
    
    # Extract CSRF token from --data-raw
    if [[ -z "$CSRF_TOKEN" ]]; then
        local normalized_curl
        normalized_curl=$(echo "$curl_content" | tr -d '\n' | sed 's/\\//g')
        
        # Extract authenticity_token value (URL encoded or not)
        # Pattern: authenticity_token=<value>&
        local raw_csrf
        raw_csrf=$(echo "$normalized_curl" | grep -oE "authenticity_token=[^&]+" | head -1 | sed 's/authenticity_token=//')
        
        if [[ -z "$raw_csrf" ]]; then
            echo -e "${RED}Error: Could not extract CSRF token from curl file${NC}"
            echo "Expected: --data-raw '...authenticity_token=<value>&...'"
            exit 1
        fi
        
        # URL decode the CSRF token (handle %3D -> =)
        CSRF_TOKEN=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$raw_csrf'))")
    fi
    
    # Extract base URL if present
    if [[ "$BASE_URL" == "https://api.va.gov" ]]; then
        local extracted_url
        extracted_url=$(echo "$curl_content" | grep -oE "https://[^/]+/flipper" | head -1 | sed 's|/flipper||')
        if [[ -n "$extracted_url" ]]; then
            BASE_URL="$extracted_url"
        fi
    fi
}

# Parse command line arguments
FEATURE=""
COOKIES=""
CSRF_TOKEN=""
EMAILS=""
INPUT_FILE=""
CURL_FILE=""
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--feature)
            FEATURE="$2"
            shift 2
            ;;
        -k|--cookies)
            COOKIES="$2"
            shift 2
            ;;
        -c|--csrf)
            CSRF_TOKEN="$2"
            shift 2
            ;;
        -r|--curl-file)
            CURL_FILE="$2"
            shift 2
            ;;
        -e|--emails)
            EMAILS="$2"
            shift 2
            ;;
        -i|--input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        -u|--base-url)
            BASE_URL="$2"
            shift 2
            ;;
        -o|--operation)
            OPERATION="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# If curl file provided, parse it
if [[ -n "$CURL_FILE" ]]; then
    parse_curl_file "$CURL_FILE"
    
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}Extracted from curl file:${NC}"
        echo "  Feature:    $FEATURE"
        echo "  Base URL:   $BASE_URL"
        echo "  CSRF Token: ${CSRF_TOKEN:0:20}..."
        echo "  Cookies:    ${COOKIES:0:50}..."
        echo ""
    fi
fi

# Validate required parameters
if [[ -z "$FEATURE" ]]; then
    echo -e "${RED}Error: Feature name is required (use -f or provide via -r curl file)${NC}"
    usage
fi

if [[ -z "$COOKIES" ]]; then
    echo -e "${RED}Error: Cookies string is required (use -k or provide via -r curl file)${NC}"
    usage
fi

if [[ -z "$CSRF_TOKEN" ]]; then
    echo -e "${RED}Error: CSRF token is required (use -c or provide via -r curl file)${NC}"
    usage
fi

if [[ -z "$EMAILS" && -z "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: Either --emails or --input-file is required${NC}"
    usage
fi

# Build email list
EMAIL_LIST=()

if [[ -n "$EMAILS" ]]; then
    IFS=',' read -ra EMAIL_LIST <<< "$EMAILS"
fi

if [[ -n "$INPUT_FILE" ]]; then
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo -e "${RED}Error: Input file not found: $INPUT_FILE${NC}"
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        line=$(echo "$line" | xargs)  # Trim whitespace
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            EMAIL_LIST+=("$line")
        fi
    done < "$INPUT_FILE"
fi

if [[ ${#EMAIL_LIST[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No valid email addresses provided${NC}"
    exit 1
fi

echo -e "${GREEN}Flipper Feature Toggle User Addition Script${NC}"
echo "=============================================="
echo "Feature:    $FEATURE"
echo "Base URL:   $BASE_URL"
echo "Operation:  $OPERATION"
echo "Users:      ${#EMAIL_LIST[@]}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

# URL encode function
urlencode() {
    local string="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('$string', safe=''))"
}

# Process each email
SUCCESS_COUNT=0
FAILURE_COUNT=0

for email in "${EMAIL_LIST[@]}"; do
    email=$(echo "$email" | xargs)  # Trim whitespace
    
    if [[ -z "$email" ]]; then
        continue
    fi
    
    echo -n "Adding: $email ... "
    
    # URL encode the email and CSRF token
    ENCODED_EMAIL=$(urlencode "$email")
    ENCODED_CSRF=$(urlencode "$CSRF_TOKEN")
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC}"
        continue
    fi
    
    # Make the API call
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "${BASE_URL}/flipper/features/${FEATURE}/actors" \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -H 'Origin: '"${BASE_URL}" \
        -H 'Referer: '"${BASE_URL}/flipper/features/${FEATURE}" \
        -H 'Sec-Fetch-Dest: document' \
        -H 'Sec-Fetch-Mode: navigate' \
        -H 'Sec-Fetch-Site: same-origin' \
        -H 'Sec-Fetch-User: ?1' \
        -H 'Upgrade-Insecure-Requests: 1' \
        -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36' \
        -b "${COOKIES}" \
        --data-raw "authenticity_token=${ENCODED_CSRF}&operation=${OPERATION}&value=${ENCODED_EMAIL}" \
        2>&1)
    
    # Extract HTTP status code (last line)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Check result
    if [[ "$HTTP_CODE" =~ ^(200|201|302|303)$ ]]; then
        echo -e "${GREEN}Success (HTTP $HTTP_CODE)${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}Failed (HTTP $HTTP_CODE)${NC}"
        ((FAILURE_COUNT++))
        
        # Show error details if available
        if [[ -n "$BODY" && "$BODY" != *"<!DOCTYPE"* ]]; then
            echo "  Error: $BODY"
        fi
    fi
    
    # Small delay to avoid rate limiting
    sleep 0.5
done

echo ""
echo "=============================================="
echo -e "Results: ${GREEN}$SUCCESS_COUNT successful${NC}, ${RED}$FAILURE_COUNT failed${NC}"

if [[ $FAILURE_COUNT -gt 0 ]]; then
    exit 1
fi
