# 5. Created Service Class

Date: 2025-03-07

## Status

Accepted

## Context

Implemented a BPDS service class that handles data submissions and retrievals to and from the BPDS system. Additionally added a flipper to enable the ability to toggle this feature in each environment.

## Decision

With the service class in place, the next step would be to create some database tables to track submissions and persist responses from the BPDS endpoint.

## Consequences

Adding this service class allows us to programatically POST JSON data to BPDS or GET data from BPDS using a unique bpds_id.
