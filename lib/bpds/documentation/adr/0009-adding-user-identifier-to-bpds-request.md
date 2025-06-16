# 9. Adding user identifier to BPDS submission

Date: 2025-06-02

## Status

Accepted

## Context

As part of the data submitted to BPDS by the Sidekiq job, we need logic to retrieve a unique identifier that can be used to associate the user with the submission in BPDS. These identifiers are PII and cannot be logged or stored unencrypted.

## Decision

We implemented logic to determine the appropriate user identifier (participant id or file number) and included this association with the request to BPDS. As we do not want PII identifiers to be exposed due to being used as Sidekiq job parameters, the payload is encrypted during processing.

The logic is as follows:
1) If the user is LOA3, we use the user's ICN to look up the user in MPI and obtain their profile. The MPI profile contains `participant_id`. If there is a `participant_id`, we send it to BPDS.

2) If the user is LOA1, we use BGS to look up the user.
  * If `participant_id` is present in the response, we send it to BPDS.
  * If `participant_id` is not present in the response, we check if `file_number` is present and include `file_number` in the request to BPDS instead.

3) If the user is unauthenticated, we use BGS to look up the user.
  * If `participant_id` is present in the response, we send it to BPDS.
  * If `participant_id` is not present in the response, we check if `file_number` is present and include `file_number` in the request to BPDS instead.

4) If no available identifiers are present, we log that no identifier was found for the saved claim and skip the BPDS job.

## Consequences

This change allows user identifiers to be included in the submission to BPDS when a user submits a form. Logging and metrics have been added to a [Datadog dashboard](https://vagov.ddog-gov.com/dashboard/2k5-e24-m9y) for monitoring purposes.
