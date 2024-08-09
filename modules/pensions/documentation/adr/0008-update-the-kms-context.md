# 8. Update the KMS Context

Date: 2024-08-08

## Status

Accepted

## Context

The encryption context of a KMS encryption property such as our claim form on the new class should work and be backwards compatible with the old model. Currently when trying to access the encrypted data from the old class or vice versa the process fails with a decryption error.

## Decision

We are adding a kms context definition to the module saved claim model and creating a migration script to address this issue. This context is currently based on the old model namespace.

## Consequences

After running the migration script and swapping the encryption context of the models, we should be able to have both models access the encrypted data from all periods.
