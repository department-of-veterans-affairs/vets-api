# 4. Successfully Connected to BPDS

Date: 2025-02-04

## Status

Accepted

## Context

The JWT Encoder was implemented in addition to setting up a forward proxy to be able to access the BPDS dev environment locally via SSH tunnelling. With these 2 components implemented, we were able to successfully tunnel to the BPDS dev endpoint using the tokens generated from our new JWT token generator. We were able to test connectivity by running POST and GET calls using test data.

## Decision

After manually curling to the BPDS endpoint, the next step was to create a service class within vets-api to be able to programatically connect to the BPDS endpoint.

## Consequences

Establishing this JWT encoder allows us to programatically generate a valid BPDS access token whenever needed.
