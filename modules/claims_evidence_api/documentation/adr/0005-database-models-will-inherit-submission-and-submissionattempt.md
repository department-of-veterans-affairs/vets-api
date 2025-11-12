# 5. Database models will inherit Submission and SubmissionAttempt

Date: 2025-07-11

## Status

Accepted

## Context

There is a need to maintain a record of the requests made with the service, and the latest status of any submission.

## Decision

The models used will inherit/extend the general Submission and SubmissionAttempt models in vets-api.

## Consequences

The base set up and form of each submission will be consistent with other services using the same structure. Certain fields will need to be aliased to be relevant to the ClaimsEvidence module.
