# Flipper Bulk User Addition Script

A utility script to add multiple users to Flipper feature toggles in bulk.

## Overview

This script automates the process of adding users (by email address) to Flipper feature toggles. It's useful when you need to enable a feature flag for many users at once, rather than adding them one-by-one through the Flipper UI.

## Prerequisites

- `curl` - for making HTTP requests
- `python3` - for URL encoding/decoding
- Access to the Flipper UI at `https://api.va.gov/flipper`

## Quick Start

### 1. Get Authentication Credentials

1. Log into the Flipper UI at `https://api.va.gov/flipper`
2. Navigate to the feature toggle you want to modify
3. Open browser DevTools (F12) → **Network** tab
4. Manually add one user via the UI (this creates a POST request)
5. Right-click the POST request → **Copy as cURL**
6. Paste into a text file (e.g., `curl_command.txt`)

### 2. Run the Script

```bash
# Add a single user
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user@va.gov'

# Add multiple users (comma-separated)
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user1@va.gov,user2@va.gov,user3@va.gov'

# Add users from a file (one email per line)
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -i emails.txt

# Dry run (see what would happen without making changes)
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user@va.gov' -d

# Verbose mode (see extracted values)
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user@va.gov' -v
```

## Usage

```
./script/flipper_bulk_users/flipper_add_users.sh [OPTIONS]

Required Options (choose one method):

  Method 1 - From curl file (recommended):
    -r, --curl-file     Path to file containing curl command copied from browser

  Method 2 - Manual parameters:
    -f, --feature       Feature toggle name
    -k, --cookies       Full cookie string from browser
    -c, --csrf          CSRF/authenticity token

One of these is required:
  -e, --emails        Comma-separated list of email addresses
  -i, --input-file    File containing email addresses (one per line)

Optional:
  -u, --base-url      Base URL (default: https://api.va.gov)
  -o, --operation     Operation: enable or disable (default: enable)
  -d, --dry-run       Show what would be done without making requests
  -v, --verbose       Show extracted values from curl file
  -h, --help          Show help message
```

## Examples

### Example 1: Add Users from Curl File

```bash
# Copy curl from browser and save to file
pbpaste > curl_command.txt

# Add users
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user1@va.gov,user2@va.gov'
```

### Example 2: Add Users from Email List File

Create `emails.txt`:
```
user1@va.gov
user2@va.gov
# This is a comment (ignored)
user3@va.gov
```

Run:
```bash
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -i emails.txt
```

### Example 3: Disable Users from a Toggle

```bash
./script/flipper_bulk_users/flipper_add_users.sh -r curl_command.txt -e 'user@va.gov' -o disable
```

### Example 4: Manual Parameters (if curl file doesn't work)

```bash
./script/flipper_bulk_users/flipper_add_users.sh \
  -f mhv_accelerated_delivery_allergies_enabled \
  -k 'api_session=xxx; TS01f27c67=yyy; ...' \
  -c 't4JYCitbgU4zD4wMVaYCI0Bk7CuZPwtEu-ChXvWFVzA=' \
  -e 'user@va.gov'
```

## How It Works

1. **Parses the curl command** to extract:
   - Feature toggle name from the URL
   - All cookies (including session cookies)
   - CSRF token from the form data

2. **For each email address**:
   - URL-encodes the email and CSRF token
   - Makes a POST request to `/flipper/features/<feature>/actors`
   - Reports success or failure

3. **Rate limiting**: Adds a 0.5 second delay between requests to avoid overwhelming the server.

## Troubleshooting

### HTTP 500 Error

The session has likely expired. Sessions typically last 15-30 minutes. Get fresh credentials by:
1. Refreshing the Flipper UI page
2. Repeating the "Copy as cURL" process
3. Re-running the script with the new curl file

### "Could not extract cookies" Error

Make sure the curl command includes the `-b` flag with cookies. The full curl command from Chrome DevTools should include this.

### "Could not extract CSRF token" Error

Make sure the curl command includes `--data-raw` with `authenticity_token`. This should be present if you copied the curl from a successful POST request.

## Security Notes

- **Session tokens expire quickly** - You'll need to refresh credentials periodically
- **Don't commit curl files** - They contain session tokens. Add `*.txt` curl files to `.gitignore`
- **The script doesn't log sensitive data** - Tokens are truncated in verbose output

## Output

```
Flipper Feature Toggle User Addition Script
==============================================
Feature:    mhv_accelerated_delivery_allergies_enabled
Base URL:   https://api.va.gov
Operation:  enable
Users:      3

Adding: user1@va.gov ... Success (HTTP 302)
Adding: user2@va.gov ... Success (HTTP 302)
Adding: user3@va.gov ... Failed (HTTP 500)

==============================================
Results: 2 successful, 1 failed
```

## Exit Codes

- `0` - All users added successfully
- `1` - One or more users failed to be added, or invalid arguments
