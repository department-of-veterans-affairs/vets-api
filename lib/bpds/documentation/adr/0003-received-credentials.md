# 3. Received Credentials

Date: 2025-01-13

## Status

Accepted

## Context

We received BPDS issuers and secrets for the dev, test, and staging environments, but were not left any clear instructions on how to use them to access the BPDS API. It was later communicated that we would need to use standard JWT encoding to generate a token using the given credentials to access the BPDS endpoint.

## Decision

Without a supplementary endpoint to generate JWT tokens provided to us, it was concluded that we would need to write our own token generation script to programatically generate valid authentication tokens to access BPDS.

## Consequences

This required constant communication with the BPDS team to confirm the expected formatting of the JWT header and payloads in order to generate valid tokens.
