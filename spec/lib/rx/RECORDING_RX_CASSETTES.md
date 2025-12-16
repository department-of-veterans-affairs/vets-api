# Recording RX Cassettes

This document outlines the steps required to successfully record VCR cassettes for RX (prescription) related tests.

## Prerequisites

Before recording RX cassettes, you need to set up the proper configuration to connect to the staging MHV (My HealtheVet) services.

## Steps to Record RX Cassettes

### 1. Sync MHV RX Settings from Staging

```bash
./script/sync-settings mhv.rx staging
```

This command pulls the necessary RX service configuration from the staging environment.

### 2. Sync MHV API Gateway Settings from Staging

```bash
./script/sync-settings mhv.api_gateway staging
```

This command pulls the API gateway configuration required for MHV service communication.

### 3. Set Up Local Host Forwarding

After running the sync-settings script, follow the instructions provided by the script to forward the `mhv.api_gateway.hosts.pharmacy` host to your local environment using SSM.

### 4. Copy Settings to Test Configuration

Copy the synchronized settings to your test configuration file:

```bash
# Copy relevant settings from the synced configuration
cp config/settings/staging.yml config/settings/test.local.yml
```

**Note:** You may need to manually copy only the relevant MHV sections rather than the entire file to avoid overriding other test-specific settings.

### 5. Disable Certificate Validation (Temporary)

For recording purposes, you'll need to disable SSL certificate validation in the Faraday HTTP client. 

**Current approach:** Modify the Faraday initializer to skip SSL verification during cassette recording.

**TODO:** Implement a more elegant solution, such as:
- Using a feature flag to conditionally disable SSL verification
- Adding a test-specific configuration option
- Using environment variables to control SSL verification behavior

### 6. Remove Existing Session Cassette

Before recording new cassettes, remove any existing session cassette that might interfere:

```bash
rm spec/support/vcr_cassettes/rx_client/session.yml
```

### 7. Run Tests to Record Cassettes

With the configuration in place, run the RX-related tests to generate new VCR cassettes:

```bash
bundle exec rspec spec/lib/rx/ --record=new_episodes
```

## Important Notes

- **Security:** Never commit staging credentials or disable SSL verification in production code
- **Cleanup:** Remember to revert any temporary configuration changes after recording cassettes
- **Review:** Always review recorded cassettes to ensure no sensitive data is included before committing

## Troubleshooting

If you encounter issues:

1. Verify that all settings are properly synchronized
2. Check that host forwarding is correctly configured
3. Ensure that the staging services are accessible
4. Confirm that existing cassettes are removed before recording new ones

## Future Improvements

- Automate the certificate validation disable/enable process
- Create a dedicated script for RX cassette recording
- Add validation to ensure cassettes don't contain sensitive information