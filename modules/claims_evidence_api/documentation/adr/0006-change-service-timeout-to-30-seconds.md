# 6. change service timeout to 30 seconds

Date: 2025-10-03

## Status

Accepted

## Context

The current ClaimsEvidence timeout is the default 15 seconds, but the endpoint has an SLA of 30. We have been seeing 500 Gateway Timeout errors being returned regularly.

## Decision

Add a setting for claims_evidence_api to increase the read/write timeout to 30 seconds.

## Consequences

This may/will require adding the service paths to the long timeout bulkhead.
