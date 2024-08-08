# 8. Update the KMS Context

Date: 2024-08-08

## Status

Accepted

## Context

The encryption context on the new class should work and be backwards compatible with the old model names. When trying to access the encrypted data from the old class or vice versa the process fails.

## Decision

We are adding a kms context definition to the module saved claim model and creating a migration script to address this issue.

## Consequences

After running the migration script and swapping the encryption context of the models, we should be able to have both models access the encrypted data from all periods.
