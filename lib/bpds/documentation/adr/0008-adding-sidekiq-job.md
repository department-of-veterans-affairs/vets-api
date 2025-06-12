# 8. Adding sidekiq job

Date: 2025-05-08

## Status

Accepted

## Context

With all the models and database tables in place, we need logic to handle creating new submissions and attempts, handle retries of failed attempts, and proper monitoring to log and track various metrics regarding BPDS submissions.

## Decision

We implemented a sidekiq job that will use our service class to attempt to POST JSON data automatically when a user submits a new application. This job tracks all Datadog metrics and provides ample logging to provide visibility when debugging.

## Consequences

This change allows data to be submitted to BPDS automatically when a user submits a form and is the final step in the MVP for BPDS integration with vets-api.
